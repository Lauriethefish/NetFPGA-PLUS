NFPLUS_FOLDER ?= $(abspath ../../../..)
export NFPLUS_FOLDER
export NF_PROJECT_NAME := quic_encrypt
export NF_DESIGN_DIR := $(abspath ..)
PYTHON_BNRY ?= $(NFPLUS_FOLDER)/.venv/bin/python3
export PYTHON_BNRY
TESTNAME ?= both_passthrough

.PHONY: all clean sim simgui simclean

all:
	vivado -mode batch -source tcl/quic_encrypt_ip.tcl

clean:
	rm -rf ip_* vivado*.* *.xml xgui/ .Xil* *.*~ *.zip project/

sim: simclean
	vivado -mode batch -source tcl/quic_encrypt_sim.tcl -tclargs $(TESTNAME)
	test -s ../test/single_expected.axi -a -s ../test/single_log.axi
	cd ../test && $(PYTHON_BNRY) $(NFPLUS_FOLDER)/tools/scripts/nf_sim_reconcile_axi_logs.py

simgui: simclean
	vivado -mode gui -source tcl/quic_encrypt_sim.tcl -tclargs $(TESTNAME)
	test -s ../test/single_expected.axi -a -s ../test/single_log.axi
	cd ../test && $(PYTHON_BNRY) $(NFPLUS_FOLDER)/tools/scripts/nf_sim_reconcile_axi_logs.py

simclean:
	rm -rf project/ .Xil/ vivado*.*
	rm -f ../test/*.axi ../test/*.log ../test/portconfig.sim ../test/seed
