PART_BASECONFIG ?= lfe5u-85f
PART_NEXTPNR ?= --85k

PROGRAM ?= blinky

# Sources
TOP_MODULE = ACoreChip
VLOGDIR = rtl/
VLOGMODS = top.v ACoreChip.v AsyncResetSyncBB.v
VLOGSRC = $(addprefix $(VLOGDIR), $(VLOGMODS))
CONSTRAINTS = constr/constr.lpf

# Targets
NETLIST = build/$(TOP_MODULE).json
BITSTREAM_ASC = build/$(TOP_MODULE).config
BITSTREAM = build/$(TOP_MODULE).bit

.PHONY: all prog_fw prog_bitstream clean

all: $(BITSTREAM)

fw:
	cd sw/riscv-c-tests && ./configure
	make -C sw/riscv-c-tests

prog_fw: fw
	python3 utils/tcp_prog.py sw/riscv-c-tests/src/$(PROGRAM)/main.elf

prog_bitstream: $(BITSTREAM)
	openFPGALoader --bitstream $(BITSTREAM) --board=ulx3s

$(NETLIST): $(VLOGSRC)
	@mkdir -p $(@D)
	yosys -l build/synth.log -p 'synth_ecp5 -noflatten -top top -json $@' $^

$(BITSTREAM_ASC): $(NETLIST) $(CONSTRAINTS)
	nextpnr-ecp5 -l build/pnr.log --json $(NETLIST) --lpf $(CONSTRAINTS) $(PART_NEXTPNR) --textcfg $@

$(BITSTREAM): $(BITSTREAM_ASC)
	ecppack --input $< --bit $@

clean:
	rm -rf build
