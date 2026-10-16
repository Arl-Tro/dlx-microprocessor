# Select which file to use as top level
set TESTBENCH_FILE "..\\VHDL_Testbenches\\tb_alu_adder.vhd" 

# Set MEM_FILE to the input memory file relative to current directory
set MEM_FILE "../../asm_example/test_jump.mem"

# Compile the design
do compile_all_smart.tcl

puts "Current working directory: [pwd]"

# Point the logical work library at the library created by the compile script.
set work_library [file normalize [file join [pwd] build work]]
vmap work $work_library

# Start simulation
vsim  work.tb_alu -t 100fs -voptargs=+acc -wlfdeleteonquit -default_radix decimal

# Add waves
quietly add wave *
quietly add wave sim:/tb_alu/ALU_CMP/ADDER_INST/CARRY_GEN/Co

quietly run 300ns
quietly wave zoom full