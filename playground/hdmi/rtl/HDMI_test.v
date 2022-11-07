// (c) fpga4fun.com & KNJN LLC 2013

////////////////////////////////////////////////////////////////////////
module HDMI_test(
	input pixclk,  // 25MHz
	output [2:0] TMDSp, TMDSn,
	output TMDSp_clock, TMDSn_clock
);

////////////////////////////////////////////////////////////////////////
reg [9:0] CounterX, CounterY;
reg hSync, vSync, DrawArea;
always @(posedge pixclk) DrawArea <= (CounterX<640) && (CounterY<480);

always @(posedge pixclk) CounterX <= (CounterX==799) ? 0 : CounterX+1;
always @(posedge pixclk) if(CounterX==799) CounterY <= (CounterY==524) ? 0 : CounterY+1;

always @(posedge pixclk) hSync <= (CounterX>=656) && (CounterX<752);
always @(posedge pixclk) vSync <= (CounterY>=490) && (CounterY<492);

////////////////
wire [7:0] W = {8{CounterX[7:0]==CounterY[7:0]}};
wire [7:0] A = {8{CounterX[7:5]==3'h2 && CounterY[7:5]==3'h2}};
reg [7:0] red, green, blue;
always @(posedge pixclk) red <= ({CounterX[5:0] & {6{CounterY[4:3]==~CounterX[4:3]}}, 2'b00} | W) & ~A;
always @(posedge pixclk) green <= (CounterX[7:0] & {8{CounterY[6]}} | W) & ~A;
always @(posedge pixclk) blue <= CounterY[7:0] | W | A;

////////////////////////////////////////////////////////////////////////
wire [9:0] TMDS_red, TMDS_green, TMDS_blue;
TMDS_encoder encode_R(.clk(pixclk), .VD(red  ), .CD(2'b00)        , .VDE(DrawArea), .TMDS(TMDS_red));
TMDS_encoder encode_G(.clk(pixclk), .VD(green), .CD(2'b00)        , .VDE(DrawArea), .TMDS(TMDS_green));
TMDS_encoder encode_B(.clk(pixclk), .VD(blue ), .CD({vSync,hSync}), .VDE(DrawArea), .TMDS(TMDS_blue));

wire clk_TMDS, DCM_TMDS_CLKFX;  // 25MHz x 10 = 250MHz
////////////////////////////////////////////////////////////////////////
// Spartan 6 maybe?
// DCM_SP #(.CLKFX_MULTIPLY(10)) DCM_TMDS_inst(.CLKIN(pixclk), .CLKFX(DCM_TMDS_CLKFX), .RST(1'b0));
// BUFG BUFG_TMDSp(.I(DCM_TMDS_CLKFX), .O(clk_TMDS));
////////////////////////////////////////////////////////////////////////
// ECP5
pll tmds_250mhz_pll(.clkin(pixclk), .clkout0(DCM_TMDS_CLKFX));
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
OLVDS OBUFDS_clock(.A(pixclk), .Z(TMDSp_clock), .ZN(TMDSn_clock));
endmodule

////////////////////////////////////////////////////////////////////////
// diamond 3.7 accepts this PLL
// diamond 3.8-3.9 is untested
// diamond 3.10 or higher is likely to abort with error about unable to use feedback signal
// cause of this could be from wrong CPHASE/FPHASE parameters
module pll
(
    input clkin, // 25 MHz, 0 deg
    output clkout0, // 250 MHz, 0 deg
    output locked
);
(* FREQUENCY_PIN_CLKI="25" *)
(* FREQUENCY_PIN_CLKOP="250" *)
(* ICP_CURRENT="12" *) (* LPF_RESISTOR="8" *) (* MFG_ENABLE_FILTEROPAMP="1" *) (* MFG_GMCREF_SEL="2" *)
EHXPLLL #(
        .PLLRST_ENA("DISABLED"),
        .INTFB_WAKE("DISABLED"),
        .STDBY_ENABLE("DISABLED"),
        .DPHASE_SOURCE("DISABLED"),
        .OUTDIVIDER_MUXA("DIVA"),
        .OUTDIVIDER_MUXB("DIVB"),
        .OUTDIVIDER_MUXC("DIVC"),
        .OUTDIVIDER_MUXD("DIVD"),
        .CLKI_DIV(1),
        .CLKOP_ENABLE("ENABLED"),
        .CLKOP_DIV(2),
        .CLKOP_CPHASE(0),
        .CLKOP_FPHASE(0),
        .FEEDBK_PATH("CLKOP"),
        .CLKFB_DIV(10)
    ) pll_i (
        .RST(1'b0),
        .STDBY(1'b0),
        .CLKI(clkin),
        .CLKOP(clkout0),
        .CLKFB(clkout0),
        .CLKINTFB(),
        .PHASESEL0(1'b0),
        .PHASESEL1(1'b0),
        .PHASEDIR(1'b1),
        .PHASESTEP(1'b1),
        .PHASELOADREG(1'b1),
        .PLLWAKESYNC(1'b0),
        .ENCLKOP(1'b0),
        .LOCK(locked)
        );
endmodule