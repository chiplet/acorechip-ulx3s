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
    output wire [3:0] o_gpo // expose only 4 LSB bits
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
    .io_debug_led           (o_debug_led),
    //.io_gpi                 (i_gpi),
    .io_gpo                 (acorechip_gpo)
);

assign o_gpo = acorechip_gpo[3:0];
assign o_tdo = acorechip_TDO_driven ? acorechip_TDO_data : 1'bz;

endmodule