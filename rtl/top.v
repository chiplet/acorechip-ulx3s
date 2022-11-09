`default_nettype none

module top (
    // System clock and reset
    input  wire i_clk_25mhz,
    //input  wire i_reset,

    // Status LEDs
    output wire o_core_fault,
    output reg  o_blinky,
    output wire o_debug_led,

    // JTAG
    input  wire i_tck,
    input  wire i_tms,
    input  wire i_tdi,
    output wire o_tdo,
    input  wire i_trstn,

    // GPIO
    //input  wire [31:0] i_gpi,
    output wire [3:0] o_gpo, // expose only 4 LSB bits

    // UART
    output wire o_tx,
    input  wire i_rx,

    // debug clock out
    // output wire clk25, clk250,

    // HDMI out
    output reg  [2:0] TMDSp, TMDSn,
	output reg        TMDSp_clock, TMDSn_clock
);

// blinky blink! (blinky to test flow and constraints)
parameter blink_thresh = 25000000;
parameter blink_cnt_width = $clog2(blink_thresh);
reg [blink_cnt_width-1:0] blink_cnt = 0;
initial o_blinky = 0;
always @(posedge i_clk_25mhz) begin
    blink_cnt <= blink_cnt + 1;
    if (blink_cnt >= blink_thresh) begin
        blink_cnt <= 0;
        o_blinky <= !o_blinky;
    end
end

wire        acorechip_TDO_data;
wire        acorechip_TDO_driven;
wire [31:0] acorechip_gpo;
wire        acorechip_tx, acorechip_rx;
wire        data_en, hsync, vsync;
wire [7:0]  r, g, b;

ACoreChip acorechip (
    .clock                  (i_clk_25mhz),
    .reset                  (!i_trstn), // horrible hack
    .io_jtag_TCK            (i_tck),
    .io_jtag_TMS            (i_tms),
    .io_jtag_TDI            (i_tdi),
    .io_jtag_TRSTn          (i_trstn),
    .io_jtag_TDO_data       (acorechip_TDO_data),
    .io_jtag_TDO_driven     (acorechip_TDO_driven),
    .io_core_fault          (o_core_fault),
    //.io_debug_led           (o_debug_led),
    //.io_gpi                 (i_gpi),
    .io_gpo                 (acorechip_gpo),
    .io_tx                  (acorechip_tx),
    .io_rx                  (acorechip_rx),

    // vga
    .io_data_en             (data_en),
    .io_hsync               (hsync),
    .io_vsync               (vsync),
    .io_r                   (r),
    .io_g                   (g),
    .io_b                   (b)
);

assign o_gpo = acorechip_gpo[3:0];
assign o_tdo = acorechip_TDO_driven ? acorechip_TDO_data : 1'bz;
assign o_tx = acorechip_tx;

////////////////////////////////////////////////////////////////////////
wire [9:0] TMDS_red, TMDS_green, TMDS_blue;
TMDS_encoder encode_R(.clk(i_clk_25mhz), .VD(r), .CD(2'b00)        , .VDE(data_en), .TMDS(TMDS_red));
TMDS_encoder encode_G(.clk(i_clk_25mhz), .VD(g), .CD(2'b00)        , .VDE(data_en), .TMDS(TMDS_green));
TMDS_encoder encode_B(.clk(i_clk_25mhz), .VD(b), .CD({vsync,hsync}), .VDE(data_en), .TMDS(TMDS_blue));

wire clk_TMDS, DCM_TMDS_CLKFX;  // 25MHz x 10 = 250MHz
////////////////////////////////////////////////////////////////////////
// Spartan 6 maybe?
// DCM_SP #(.CLKFX_MULTIPLY(10)) DCM_TMDS_inst(.CLKIN(i_clk_25mhz), .CLKFX(DCM_TMDS_CLKFX), .RST(1'b0));
// BUFG BUFG_TMDSp(.I(DCM_TMDS_CLKFX), .O(clk_TMDS));
////////////////////////////////////////////////////////////////////////
// ECP5
pll tmds_250mhz_pll(.clkin(i_clk_25mhz), .clkout0(DCM_TMDS_CLKFX));
assign clk_TMDS = DCM_TMDS_CLKFX; // FIXME: is buffering necessary?



////////////////////////////////////////////////////////////////////////
reg [3:0] TMDS_mod10=0;  // modulus 10 counter
reg [9:0] TMDS_shift_red=0, TMDS_shift_green=0, TMDS_shift_blue=0;
reg TMDS_shift_load=0;
always @(posedge clk_TMDS) TMDS_shift_load <= (TMDS_mod10==4'd9);

always @(posedge clk_TMDS)
begin
	TMDS_shift_red   <= TMDS_shift_load ? TMDS_red   : TMDS_shift_red  [9:1];
	TMDS_shift_green <= TMDS_shift_load ? TMDS_green : TMDS_shift_green[9:1];
	TMDS_shift_blue  <= TMDS_shift_load ? TMDS_blue  : TMDS_shift_blue [9:1];	
	TMDS_mod10 <= (TMDS_mod10==4'd9) ? 4'd0 : TMDS_mod10+4'd1;
end

OLVDS OBUFDS_red  (.A(TMDS_shift_red  [0]), .Z(TMDSp[2]), .ZN(TMDSn[2]));
OLVDS OBUFDS_green(.A(TMDS_shift_green[0]), .Z(TMDSp[1]), .ZN(TMDSn[1]));
OLVDS OBUFDS_blue (.A(TMDS_shift_blue [0]), .Z(TMDSp[0]), .ZN(TMDSn[0]));
OLVDS OBUFDS_clock(.A(i_clk_25mhz), .Z(TMDSp_clock), .ZN(TMDSn_clock));

endmodule