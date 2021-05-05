# test name
TEST_NAME:=axi_router
VHDL_EX:=vhd
STOP_TIME:=100us

# compiler settings
GHDL_CMD:=ghdl
GHDL_FLAGS:=--ieee=synopsys --warn-no-vital-generic
# --std=08

# directories
TESTBENCH_DIR:=./testbench
SOURCE_DIR:=./full_noc
WORK_DIR:=./ghdlwork

# files
SOURCE_FILES:=$(shell find $(SOURCE_DIR) -name '*.$(VHDL_EX)')
TESTBENCH_FILES:=$(shell find $(TESTBENCH_DIR) -name '*.$(VHDL_EX)')

# vcd file
VCD_FILE:=$(TEST_NAME).vcd


all:directory compile run

directory:
	mkdir -p $(WORK_DIR) $(SOURCE_DIR) $(TESTBENCH_DIR)

compile:
	$(GHDL_CMD) -i $(GHDL_FLAGS) --workdir=$(WORK_DIR) --work=work $(TESTBENCH_FILES) $(SOURCE_FILES)
	$(GHDL_CMD) -m $(GHDL_FLAGS) --workdir=$(WORK_DIR) --work=work $(TEST_NAME)

run:
	$(GHDL_CMD) -r $(GHDL_FLAGS) --workdir=$(WORK_DIR) --work=work $(TEST_NAME) --vcd=$(VCD_FILE) --ieee-asserts=disable --stop-time=$(STOP_TIME)

view:
	gtkwave $(VCD_FILE)

clean:
	rm -f *.vcd *.txt
	rm -rf $(WORK_DIR)/*.cf
	rm -rf ./data/gen_rec/out/*


tree:
	$(GHDL_CMD) -r $(GHDL_FLAGS) --workdir=$(WORK_DIR) --work=work $(TEST_NAME) --disp-tree --no-run > tree.txt