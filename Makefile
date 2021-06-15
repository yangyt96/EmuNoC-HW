# test name
TEST_NAME:=top_tb
VHDL_EX:=vhd
STOP_TIME:=1000ns

# compiler settings  --ieee=[synopsys none standard mentor]  --warn-no-vital-generic --std=08
GHDL_CMD:=ghdl
GHDL_FLAGS:= --warn-no-vital-generic --std=08

# directories
TESTBENCH_DIR:=./testbench
SOURCE_DIR:=./source
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
	rm -rf ./testdata/gen_rec/out/*
	rm -rf ./testdata/pic/out/*


tree:
	$(GHDL_CMD) -r $(GHDL_FLAGS) --workdir=$(WORK_DIR) --work=work $(TEST_NAME) --disp-tree --no-run > tree.txt


install:
	git clone https://github.com/ghdl/ghdl.git
	cd ghdl
	sudo apt install gnat
	./configure --prefix=/usr/local
	make
	make install
	cd ..
# sudo rm -rf ghdl
