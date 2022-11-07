PART_BASECONFIG ?= lfe5u-85f
PART_NEXTPNR ?= --85k

# Sources
TOP_MODULE = HDMI_test
VLOGDIR = rtl/
VLOGMODS = $(TOP_MODULE).v TMDS_encoder.v
VLOGSRC = $(addprefix $(VLOGDIR), $(VLOGMODS))
CONSTRAINTS = constr/constr.lpf

# Targets
NETLIST = build/$(TOP_MODULE).json
BITSTREAM_ASC = build/$(TOP_MODULE).config
BITSTREAM = build/$(TOP_MODULE).bit

.PHONY: all prog_fw prog_bitstream clean

all: $(BITSTREAM)

prog_bitstream: $(BITSTREAM)
	openFPGALoader --bitstream $(BITSTREAM) --board=ulx3s

$(NETLIST): $(VLOGSRC)
	@mkdir -p $(@D)
	yosys -l build/synth.log -p 'synth_ecp5 -noflatten -top $(TOP_MODULE) -json $@' $^

$(BITSTREAM_ASC): $(NETLIST) $(CONSTRAINTS)
	nextpnr-ecp5 -l build/pnr.log --json $(NETLIST) --lpf $(CONSTRAINTS) $(PART_NEXTPNR) --textcfg $@

$(BITSTREAM): $(BITSTREAM_ASC)
	ecppack --input $< --bit $@

clean:
	rm -rf build
