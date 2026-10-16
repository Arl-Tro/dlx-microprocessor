library ieee;
use ieee.std_logic_1164.all;
use work.myTypes.all;

-- Package for types inherent to the communication among different stages through records
-- It is hereby assumed that this is for a 32 bit CPU with 5 bit addressing on the register file
package cpu_32b_types is

	constant NBIT : natural := 32; -- Datapath bit width
	constant NBIT_IDX : natural := 5; -- N' bits to address registers
	constant G_REGS : natural := 8; -- Number of global registers
	constant BLOCK_REGS : natural := 8; -- How many registers per each In/Loc/Out block?
	constant TOT_WINDOWS : natural := 4; -- How many overlapping windows should there be?
	constant DRAM_D : natural := 1024; -- How large should the DRAM be?
	constant IRAM_DEPTH : natural := 512;
	constant RAM_PRINT : natural := 65280; -- 0xFF00 address is reserved to print written data in vsim

	-- Fetch stage, control inputs
	type if_ctrl_in_t is record
		-- EN_STAGE : std_logic; -- Enable the whole stage, achieved through clock gating
		NRST_STAGE : std_logic; -- Reset the whole stage, asynchronous, ORed with the global NRST

		EN_PC : std_logic; -- Enable PC
		EN_NPC : std_logic; -- Enable NPC
		EN_IR : std_logic; -- Enable IR
		JUMP_SEL : std_logic; -- If '0' the internal NPC is written to PC (PC <= PC + 1) if EN_PC is high. If '1' NPC_IN external signal is written to PC
	end record;

	-- Fetch stage, data inputs
	type if_data_in_t is record
		NPC_IN : std_logic_vector(NBIT - 1 downto 0); -- Next program counter input for jump instructions
	end record;

	-- Fetch stage, data outputs
	type if_data_out_t is record
		NPC_OUT : std_logic_vector(NBIT - 1 downto 0); -- Next program counter output for jump instructions
		IR_OUT : std_logic_vector(NBIT - 1 downto 0); -- Current content of the IR, used by the CU  
	end record;

	-- Decode stage, control inputs
	type id_ctrl_in_t is record
		-- EN_STAGE : std_logic; -- Enable the whole stage, achieved through clock gating
		NRST_STAGE : std_logic; -- Reset the whole stage, asynchronous, ORed with the global NRST
		RD_WEN : std_logic; -- Write enable for the RD. Propagated here to provide it to the hazard/forward unit
		EN_RS1, EN_RS2, EN_RIMM : std_logic; -- Enable A, B, Immediate Registers
		W_EN_IRF : std_logic; -- Enable write of the register file
		SHORT_LONG_IMMEDIATE : std_logic; -- If '0' the short immediate is sign extended and written to the IMM register, if '1' the long immediate is written to the IMM register
		IS_RR_OP : std_logic; -- Used to select the Rd, if the current operation is RR then this should be '1' else '0'
		SIGN_IMMEDIATE : std_logic; -- If '0' the immediates are zero extended, if '1' the immediates are sign extended 
		LINK_EN : std_logic; -- If '1' the register write port is connected to the NPC, to save the lk address to go to after a subroute (lk mode)
		IS_STORE : std_logic; -- If '1' the current instruction (in decode stage) is a load and thus will use rs2
	end record;

	-- Decode stage, data inputs
	type id_data_in_t is record
		IR_IN : std_logic_vector(NBIT - 1 downto 0); -- Instruction register to be decoded
		NPC_IN : std_logic_vector(NBIT - 1 downto 0); -- Next program counter, required to be propagated
	end record;

	-- Decode stage, data outputs
	type id_data_out_t is record
		RS1_DATA, RS2_DATA : std_logic_vector(NBIT - 1 downto 0); -- Data from the RS1, RS2 registers (not directly from the register file)
		RIMM_DATA : std_logic_vector(NBIT - 1 downto 0); -- Data from the Immediate register
		RD_ADDR_OUT : std_logic_vector(NBIT_IDX - 1 downto 0); -- Decoded from IR, used during the writeback stage (registered here)
		NPC_OUT : std_logic_vector(NBIT - 1 downto 0); -- Next program counter, propagated
	end record;

	-- Execute stage, control inputs
	type ex_ctrl_in_t is record
		-- EN_STAGE : std_logic; -- Enable the whole stage, achieved through clock gating
		NRST_STAGE : std_logic; -- Reset the whole stage, asynchronous, ORed with the global NRST
		LINK_EN : std_logic;
		RD_WEN : std_logic; -- Write enable for the RD. Propagated here to provide it to the hazard/forward unit
		MUX_A_SEL, MUX_B_SEL : std_logic; -- Selection signal for the MUXes of the A and B operands of the ALU
		EN_RALUOUT : std_logic; -- Enable the output register of the ALU
		ALU_OP : aluOp; -- ALU operation selection signal
		BRANCH_MODE : branchSelection_t; -- Input to select the branch condition 
		IS_LOAD : std_logic; -- If 1, the instruction in the execute stage is a load 
	end record;

	-- Execute stage, data inputs
	type ex_data_in_t is record
		NPC_IN : std_logic_vector(NBIT - 1 downto 0); -- Next program counter, propagated
		RS1_DATA : std_logic_vector(NBIT - 1 downto 0); -- Data from the RS1
		RS2_DATA : std_logic_vector(NBIT - 1 downto 0); -- Data from the RS2
		RIMM_DATA : std_logic_vector(NBIT - 1 downto 0); -- Data from the Immediate register
		RD_ADDR_IN : std_logic_vector(NBIT_IDX - 1 downto 0); -- propagate to writeback stage
	end record;

	-- Execute stage, data outputs
	type ex_data_out_t is record
		BRANCH : std_logic; -- Will be 1 if the branch is taken, 0 if it is not
		ALU_DATA : std_logic_vector(NBIT - 1 downto 0); -- ALU Data, registered
		RAM_DATA : std_logic_vector(NBIT - 1 downto 0); -- RAM Data, to be written to RAM for Mem instruction
		NPC_OUT : std_logic_vector(NBIT - 1 downto 0); -- Next progra mcounter, to be sent to the fetch stage becuase the NPC is selected in this stage with the ALU result (Note: NOT REGISTERED!, the PC is supposed to register this)
		RD_ADDR_OUT : std_logic_vector(NBIT_IDX - 1 downto 0); -- Propagate the destination register to the writeback stage
	end record;

	-- Memory stage, control inputs
	type mem_ctrl_in_t is record
		-- EN_STAGE : std_logic; -- Enable the whole stage, achieved through clock gating
		NRST_STAGE : std_logic; -- Reset the whole stage, asynchronous, ORed with the global NRST
		RD_WEN : std_logic; -- Write enable for the RD. Propagated here to provide it to the hazard/forward unit
		DRAM_WRITE : std_logic; -- Data RAM Write Enable, when 1 write to ram when 0 read only
		EN_LMD : std_logic; -- LMD Register Latch Enable
		EN_JUMP : std_logic; -- JUMP Enable Signal for PC input MUX
		EN_PC : std_logic; -- Program Counte Latch Enable ToDo: Move, the PC is not in the memory stage actually

		SIGNED_LOAD : std_logic; -- If 0 the data read from byte/half word is zero extended, if 1 the data is sign extended
		MEM_MODE_W : std_logic; -- If 1 the full word read/written from/to the current address is written to LMD (read 32b from ram), if 0 the B/HW signal is used to select between reading/writing a byte or a half world
		MEM_MODE_B_HW : std_logic; -- If 1 a byte is loaded/written from/to memory (at the exact specified address, for any CW any of the 4B can be selected), if 0 a half word (16b) is loaded, for this to be enabled MEM_LOAD_W must be low
		-- Note: if both LOAD_W and LOAD_B_HW are 1, then a read word is performed (LOAD_W has priority)
	end record;

	-- Memory stage, data inputs
	type mem_data_in_t is record
		ALU_DATA_IN : std_logic_vector(NBIT - 1 downto 0); -- ALU Data, from Exec stage
		RAM_DATA_IN : std_logic_vector(NBIT - 1 downto 0); -- RAM Data, from Exec stage
		RD_ADDR_IN : std_logic_vector(NBIT_IDX - 1 downto 0); -- propagate to writeback stage
	end record;

	-- Memory stage, data outputs
	type mem_data_out_t is record
		ALU_DATA_OUT : std_logic_vector(NBIT - 1 downto 0); -- ALU Data, propagate to writeback
		RAM_DATA_OUT : std_logic_vector(NBIT - 1 downto 0); -- RAM Data, propagate to writeback
		RD_ADDR_OUT : std_logic_vector(NBIT_IDX - 1 downto 0); -- Propagate the destination register to the writeback stage
	end record;

	-- Writeback stage, control inputs
	type wb_ctrl_in_t is record
		-- EN_STAGE : std_logic; -- Enable the whole stage, achieved through clock gating
		NRST_STAGE : std_logic; -- Reset the whole stage, asynchronous, ORed with the global NRST
		RD_WEN : std_logic; -- Write enable for the RD. Propagated here to provide it to the hazard/forward unit
		EN_IRF_WRITE : std_logic; -- Enable write signal for the register file
		WB_SEL : std_logic; -- Set to 1 to writeback the content of the RAM or to 0 to write the alu out
	end record;

	-- Writeback stage, data inptus
	type wb_data_in_t is record
		ALU_DATA_IN : std_logic_vector(NBIT - 1 downto 0); -- ALU Data, propagate to writeback
		RAM_DATA_IN : std_logic_vector(NBIT - 1 downto 0); -- RAM Data, propagate to writeback
		RD_ADDR_IN : std_logic_vector(NBIT_IDX - 1 downto 0); -- Propagate the destination register to the writeback stage
	end record;

	-- Writeback stage, data outputs
	type wb_data_out_t is record
		RD_DATA_OUT : std_logic_vector(NBIT - 1 downto 0); -- Destination register to be sent to the IRF 
		RD_ADDR_OUT : std_logic_vector(NBIT_IDX - 1 downto 0); -- Destination register address to be sent to the IRF
		DATA_FORM_MEM : std_logic_vector(NBIT - 1 downto 0); -- single Data from the memory stage ,Give as an extra output the result of the select mux between alu data and ram load data, needed for the forwarding unit
	end record;
	-- Zero constants

	constant EXE_CTRL_ZERO : ex_ctrl_in_t := (
		NRST_STAGE => '0',
		MUX_A_SEL => '0',
		MUX_B_SEL => '0',
		EN_RALUOUT => '0',
		LINK_EN => '0',
		RD_WEN => '0',
		ALU_OP => NOP,
		BRANCH_MODE => NO_BRANCH,
		IS_LOAD => '0'
	);

	constant EXE_DIN_ZERO : ex_data_in_t := (
		NPC_IN => (others => '0'),
		RS1_DATA => (others => '0'),
		RS2_DATA => (others => '0'),
		RIMM_DATA => (others => '0'),
		RD_ADDR_IN => (others => '0')
	);

	-- Types for memory subsystem

	type rf_write_port is record
		EN_WRITE : std_logic; -- Register-file write enable
		W_ADDR : std_logic_vector(NBIT_IDX - 1 downto 0); -- Destination register address
		W_DATA : std_logic_vector(NBIT - 1 downto 0); -- Data written to the destination register
	end record;
end cpu_32b_types;