library ieee;
use ieee.std_logic_1164.all;
use WORK.constants.all;


entity CARRY_SEL_ADD is
	generic(NBIT : integer := numBit;
		NBLOCKS : integer := numBit/numBit_block);
	port(
		A : in std_logic_vector(NBIT-1 downto 0);
		B : in std_logic_vector(NBIT-1 downto 0);
		Ci : in std_logic;
		S : out std_logic_vector(NBIT-1 downto 0);
		Co : out std_logic
	);
end entity; 

architecture STRUCTURAL of CARRY_SEL_ADD is 
-- basic block of the carry select adder
	component CSA_BLOCK
		generic(NBIT : integer := numBit_block);
		port(
			A : in std_logic_vector(NBIT-1 downto 0);
			B : in std_logic_vector(NBIT-1 downto 0);
			C_IN : in std_logic;
			SUM : out std_logic_vector(NBIT-1 downto 0);
			C_OUT : out std_logic
		);
	end component;

--signal
signal carry_p : std_logic_vector(NBLOCKS downto 0);
 
begin
	
	carry_p(0)<= Ci;
	
	BLOCK_GEN : for i in 0 to NBLOCKS-1 generate
		CSA_I : CSA_BLOCK
		generic map(NBIT => numBit_block)
		port map(
			A => A(numBit_block*i+(numBit_block-1) downto numBit_block*i),
 			B => B(numBit_block*i+(numBit_block-1) downto numBit_block*i),
			C_IN => carry_p(i),
			SUM => S(numBit_block*i+(numBit_block-1) downto numBit_block*i),
			C_OUT => carry_p(i+1)
		);	
	end generate;
	Co <= carry_p(NBLOCKS);
	
end architecture;

configuration CFG_CARRY_SEL_ADD_STRUCTURAL  of CARRY_SEL_ADD is 
	for STRUCTURAL
		for BLOCK_GEN
			for all : CSA_BLOCK
				use configuration WORK.CFG_CSA_BLOCK_STRUCTURAL;
			end for;
		end for;
	end for;
end configuration CFG_CARRY_SEL_ADD_STRUCTURAL;


