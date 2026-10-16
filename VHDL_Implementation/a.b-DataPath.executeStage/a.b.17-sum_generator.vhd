library IEEE;
use ieee.std_logic_1164.all;
use WORK.constants.all;

entity SUM_GENERATOR is
	generic (
		NBIT : integer := numBit;
		NBLOCKS : integer := numBit/numBit_block);
	port (
		A : in std_logic_vector(NBIT - 1 downto 0);
		B : in std_logic_vector(NBIT - 1 downto 0);
		Cin : in std_logic_vector(NBLOCKS - 1 downto 0);
		S : out std_logic_vector(NBIT - 1 downto 0)
	);
end SUM_GENERATOR;

architecture STRUCTURAL of SUM_GENERATOR is

	-- COMPONENTS

	-- Carry select block
	component CSA
		generic (NBIT : integer := numBit_block);
		port (
			A : in std_logic_vector(NBIT - 1 downto 0);
			B : in std_logic_vector(NBIT - 1 downto 0);
			C_IN : in std_logic;
			SUM : out std_logic_vector(NBIT - 1 downto 0)
		);
	end component;
begin
	ADDER : for i in 0 to NBLOCKS - 1 generate
		CSA_I : CSA
		generic map(NBIT => numBit_block)
		port map(
			A => A(numBit_block * i + (numBit_block - 1) downto numBit_block * i),
			B => B(numBit_block * i + (numBit_block - 1) downto numBit_block * i),
			C_IN => Cin(i),
			SUM => S(numBit_block * i + (numBit_block - 1) downto numBit_block * i)
		);
	end generate;

end architecture STRUCTURAL;

configuration CFG_SUM_GENERATOR_STRUCTURAL of SUM_GENERATOR is
	for STRUCTURAL
		for ADDER
			for all : CSA
				use configuration WORK.CFG_CSA_STRUCTURAL;
			end for;
		end for;
	end for;
end configuration CFG_SUM_GENERATOR_STRUCTURAL;