PROJ = ${NF_PROJECT_NAME}

all: clean
	vivado -mode batch -source udp_checksum_calculator_sim.tcl

clean:
	rm -rf ip_*  vivado*.* *.xml xgui/ .Xil* *.*~ *.zip

sim:	simclean
	vivado -mode batch -source ../../../projects/${PROJ}/hw/tcl/${NF_PROJECT_NAME}_sim.tcl -tclargs ${TESTNAME}
	$(NFPLUS_FOLDER)/tools/scripts/nf_sim_reconcile_axi_logs.py


simgui: simclean 
	vivado -mode gui -source ../../../projects/${PROJ}/hw/tcl/$(NF_PROJECT_NAME)_sim.tcl -tclargs ${TESTNAME}
	$(NFPLUS_FOLDER)/tools/scripts/nf_sim_reconcile_axi_logs.py

simclean:
	rm -rf proj_* vivado*.* *.*~ .Xil* $(NF_DESIGN_DIR)/hw/ip_repo/ $(NF_DESIGN_DIR)/hw/project/
	rm -rf *[0-9]_{stim,expected,log}.axi
	rm -f *.axi
	rm -f portconfig.sim
	rm -f seed
	rm -f *.log
	rm -f ../test/Makefile
	rm -rf ../test/*.log
	rm -rf ../test/*.axi
	rm -rf ../test/seed
	rm -rf ../test/*.sim
	rm -rf ../test/proj_*
	rm -rf ../test/ip_repo
	rm -f ../test/vivado*.*
	rm -f ../test/*_*_*/reg_defines_${NF_PROJECT_NAME}.py
	rm -f ../test/*_*_*/reg_defines_${NF_PROJECT_NAME}.pyc
