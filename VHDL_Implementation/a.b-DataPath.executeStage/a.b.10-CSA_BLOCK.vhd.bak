library IEEE;
use IEEE.std_logic_1164.all;
use WORK.constants.all;


-- Carry select adder of NBITs

entity CSA_BLOCK is
	generic (
		NBIT : integer := numBit_block); -- How large are the input operands? (This is a CSA block, containing two NBIT adders which are supplied with carry 0 or 1, the output is selected thorugh C_IN)
	port (
		A : in std_logic_vector(NBIT - 1 downto 0);
		B : in std_logic_vector(NBIT - 1 downto 0);
		C_IN : in std_logic;
		SUM : out std_logic_vector(NBIT - 1 downto 0);
		C_OUT : out std_logic
	);
end CSA_BLOCK;

architecture STRUCTURAL of CSA_BLOCK is

	-- COMPONENTS

	component MUX21_GENERIC
		generic (NBIT : integer := NBIT); -- L.R. : Modificato NBIT dei componenti con NBIT generic, cosi` non si dipende dalla costante numBit_block e basta dare NBIT nel generic del CSA
		port (
			A : in std_logic_vector(NBIT - 1 downto 0);
			B : in std_logic_vector(NBIT - 1 downto 0);
			SEL : in std_logic;
			Y : out std_logic_vector(NBIT - 1 downto 0));

	end component;

	component RCA_GEN
		generic (
			DRCAS : time := 0 ns;
			DRCAC : time := 0 ns;
			NBIT : integer := NBIT);
		port (
			A : in std_logic_vector(NBIT - 1 downto 0);
			B : in std_logic_vector(NBIT - 1 downto 0);
			Ci : in std_logic;
			S : out std_logic_vector(NBIT - 1 downto 0);
			Co : out std_logic);
	end component;

	-- SIGNALS
	-- signals that carry the output sums of the two RCA

	signal sum_rca_cin_0, sum_rca_cin_1 : std_logic_vector(NBIT - 1 downto 0);
	-- 2 carry in signals for the two RCA, one is = '0' the other = '1'
	constant carry_0 : std_logic := '0';
	constant carry_1 : std_logic := '1';
	
	-- 2 carry out signals from the 2 adders
	signal carry_out : std_logic_vector(2 downto 0);

begin
	-- Adder that performs the sum considering carry in = '0'
	
	ADD_1 : RCA_GEN generic map(NBIT => NBIT)
	port map(
		A => A,
		B => B,
		Ci => carry_0,
		S => sum_rca_cin_0,
		Co => carry_out(0)
	);

	-- Adder that performs the sum considering carry in = '1'
	ADD_2 : RCA_GEN generic map(NBIT => NBIT)
	port map(
		A => A,
		B => B,
		Ci => carry_1,
		S => sum_rca_cin_1,
		Co => carry_out(1)
	);

	-- Multiplexer that selects the output of one of the adders depending on real carry in from previous block
	MUX_SUM : MUX21_GENERIC
	generic map(NBIT => NBIT)
	port map(
		A => sum_rca_cin_1, --RICORDARSI DI CAMBIARE. OPPURE INVERTIRE MUX21 
		B => sum_rca_cin_0,
		SEL => C_IN,
		Y => SUM
	);
	MUX_CARRY : MUX21_GENERIC
	generic map(NBIT => 1)
	port map(
		A => carry_out(1 downto 1),
		B => carry_out(0 downto 0),
		SEL => C_IN,
		Y => carry_out(2 downto 2)
	);

	C_OUT <= carry_out(2);
end architecture STRUCTURAL;

configuration CFG_CSA_BLOCK_STRUCTURAL of CSA_BLOCK is
	for STRUCTURAL

		for ADD_1 : RCA_GEN
			use configuration WORK.CFG_RCA_GEN_STRUCTURAL;
		end for;

		for ADD_2 : RCA_GEN
			use configuration WORK.CFG_RCA_GEN_STRUCTURAL;
		end for;

		for MUX_SUM : MUX21_GENERIC
			use configuration WORK.CFG_MUX21_GEN_STRUCTURAL;
		end for;
		for MUX_CARRY : MUX21_GENERIC
			use configuration WORK.CFG_MUX21_GEN_STRUCTURAL;
		end for;

end for;
end configuration;
