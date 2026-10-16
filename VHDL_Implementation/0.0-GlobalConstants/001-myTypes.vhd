library ieee;
use ieee.std_logic_1164.all;

package myTypes is
	type aluOp is (
		NOP, ADD, SUB, EQ, GT, GE, NE, LT, LT_U, LE, AND_OP, NAND_OP, OR_OP, 
		NOR_OP, XOR_OP, XNOR_OP, MULT, SLL_OP, SRL_OP, SRA_OP
	);
	
	type branchSelection_t is (
		NO_BRANCH, -- Do not branch
		BRANCH_EQZ, -- Branch if equal to 0
		BRANCH_NEQZ, -- Branch if not equal to 0
		BRANCH_ALL -- Branch no matter what
	);

	
end myTypes;

