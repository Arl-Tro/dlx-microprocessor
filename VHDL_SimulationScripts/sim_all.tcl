# Select which file to use as top level
set TESTBENCH_FILE "../VHDL_Testbenches/TB_DLX.vhd" 
# set TESTBENCH_FILE "..\\VHDL_Testbenches\\TB_DLX_BEHAVIORAL.vhd" 

# Set MEM_FILE to the input memory file to use ase assembly input
set MEM_FILE "../../asm_example/test_arith_basic.mem"
# set MEM_FILE "../../asm_example/test_memory_no_hazard.mem"
# set MEM_FILE "../../asm_example/test_jump.mem"

# Compile the design
if {[info exists do_argv] && [lsearch -exact $do_argv "--clean"] >= 0} {
    do compile_all_smart.tcl --clean
} else {
    do compile_all_smart.tcl
}



puts "Current working directory: [pwd]"

# Point the logical work library at the library created by the compile script.
set work_library [file normalize [file join [pwd] build work]]
vmap work $work_library

# Start simulation
vsim  work.TB_DLX -t 100fs -voptargs=+acc -wlfdeleteonquit -default_radix hexadecimal

# Add waves
quietly add wave *
# add wave sim:/tb_dlx/U1/DP_I/FETCH_STAGE_INST/PC/Q
# add wave sim:/tb_dlx/U1/DP_I/DECODE_STAGE_INST/REGISTER_FILE/rf
quietly add wave -position 2  sim:/tb_dlx/U1/DP_I/MEM_SYS/U_DRAM/MEMORY
quietly add wave sim:/tb_dlx/U1/DP_I/MEM_SYS/U_WRF/REGISTERS
quietly add wave sim:/tb_dlx/U1/DP_I/fetch_dout
quietly add wave sim:/tb_dlx/U1/DP_I/decode_dout
quietly add wave sim:/tb_dlx/U1/DP_I/execute_dout
quietly add wave sim:/tb_dlx/U1/DP_I/memory_dout
quietly add wave sim:/tb_dlx/U1/DP_I/writeback_dout
# add wave sim:/tb_dlx/U1/DP_I/FWD_RS1_INST/*
# add wave sim:/tb_dlx/U1/DP_I/FWD_RS2_INST/*
add wave -position end sim:/tb_dlx/U1/DP_I/CU_HAZARD_inst/*

quietly run 1000ns
quietly wave zoom full
