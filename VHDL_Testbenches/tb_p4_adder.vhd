library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use WORK.constants.all; -- libreria WORK user-defined

entity TB_P4_ADDER is
end TB_P4_ADDER;

architecture TEST of TB_P4_ADDER is
	constant WAIT_TIME : time := 20 ns; -- Defined as a const so it can easily be adjusted to fit the numbers

	-- P4 component declaration
	component P4_ADDER is
		generic (
			NBIT : integer := NumBit);
		port (
			A : in std_logic_vector(NBIT - 1 downto 0);
			B : in std_logic_vector(NBIT - 1 downto 0);
			Cin : in std_logic;
			S : out std_logic_vector(NBIT - 1 downto 0);
			Cout : out std_logic);
	end component;

	component RCA_GEN is -- Used to check the result of the addition, RCA was already tested
		generic (
			DRCAS : time := 0 ns;
			DRCAC : time := 0 ns;
			NBIT : integer := NumBit
		);
		port (
			A : in std_logic_vector(NBIT - 1 downto 0);
			B : in std_logic_vector(NBIT - 1 downto 0);
			Ci : in std_logic;
			S : out std_logic_vector(NBIT - 1 downto 0);
			Co : out std_logic);
	end component;

	signal A_32b, B_32b : std_logic_vector(31 downto 0); -- Fixed 32 bits
	signal A_tb, B_tb, S_tb, S_reference : std_logic_vector(NumBit - 1 downto 0); -- Flexible
	signal Cin_tb, Cout_tb, Cout_reference : std_logic;

begin
	-- P4 instantiation
	-- 

	-- Handle different NumBits
	A_tb <= A_32b( NumBit - 1 downto 0);
	B_tb <= B_32b( NumBit - 1 downto 0);

	DUT : P4_ADDER port map(A_tb, B_tb, Cin_tb, S_tb, Cout_tb);
	REFERENCE : RCA_GEN port map(A_tb, B_tb, Cin_tb, S_reference, Cout_reference);

	process
	begin
		-- First test
		A_32b <= x"FFFFFFFF";
		B_32b <= x"FFFFFFFF";
		Cin_tb <= '0';

		wait for WAIT_TIME;

		-- Second test
		A_32b <= x"00FFFFFF";
		B_32b <= x"00FF00FF";
		Cin_tb <= '0';

		-- Third test (all zeros)
		A_32b <= x"00000000";
		B_32b <= x"00000000";
		Cin_tb <= '0';

		wait for WAIT_TIME;

		-- Fourth test (single bit addition)
		A_32b <= x"00000001";
		B_32b <= x"00000001";
		Cin_tb <= '0';

		wait for WAIT_TIME;

		-- Fifth test (carry propagation across multiple bits)
		A_32b <= x"0000FFFF";
		B_32b <= x"00000001";
		Cin_tb <= '0';

		wait for WAIT_TIME;

		-- Sixth test (overflow boundary)
		A_32b <= x"7FFFFFFF";
		B_32b <= x"00000001";
		Cin_tb <= '0';

		wait for WAIT_TIME;

		-- Seventh test (max + small number)
		A_32b <= x"FFFFFFFF";
		B_32b <= x"00000001";
		Cin_tb <= '0';

		wait for WAIT_TIME;

		-- Eighth test (alternating pattern)
		A_32b <= x"AAAAAAAA";
		B_32b <= x"55555555";
		Cin_tb <= '0';

		wait for WAIT_TIME;

		-- Ninth test (same operands)
		A_32b <= x"12345678";
		B_32b <= x"12345678";
		Cin_tb <= '0';

		wait for WAIT_TIME;

		-- Tenth test (different random-like values)
		A_32b <= x"89ABCDEF";
		B_32b <= x"13579BDF";
		Cin_tb <= '0';

		wait for WAIT_TIME;

		-- Eleventh test (upper half active)
		A_32b <= x"FFFF0000";
		B_32b <= x"0000FFFF";
		Cin_tb <= '0';

		wait for WAIT_TIME;

		-- Twelfth test (sparse bits)
		A_32b <= x"80000001";
		B_32b <= x"00000001";
		Cin_tb <= '0';

		wait for WAIT_TIME;

		-- First test
		A_32b <= x"FFFFFFFF";
		B_32b <= x"FFFFFFFF";
		Cin_tb <= '1';

		wait for WAIT_TIME;

		-- Second test
		A_32b <= x"00FFFFFF";
		B_32b <= x"00FF00FF";

		-- Third test (all zeros)
		A_32b <= x"00000000";
		B_32b <= x"00000000";

		wait for WAIT_TIME;

		-- Fourth test (single bit addition)
		A_32b <= x"00000001";
		B_32b <= x"00000001";

		wait for WAIT_TIME;

		-- Fifth test (carry propagation across multiple bits)
		A_32b <= x"0000FFFF";
		B_32b <= x"00000001";

		wait for WAIT_TIME;

		-- Sixth test (overflow boundary)
		A_32b <= x"7FFFFFFF";
		B_32b <= x"00000001";

		wait for WAIT_TIME;

		-- Seventh test (max + small number)
		A_32b <= x"FFFFFFFF";
		B_32b <= x"00000001";

		wait for WAIT_TIME;

		-- Eighth test (alternating pattern)
		A_32b <= x"AAAAAAAA";
		B_32b <= x"55555555";

		wait for WAIT_TIME;

		-- Ninth test (same operands)
		A_32b <= x"12345678";
		B_32b <= x"12345678";

		wait for WAIT_TIME;

		-- Tenth test (different random-like values)
		A_32b <= x"89ABCDEF";
		B_32b <= x"13579BDF";

		wait for WAIT_TIME;

		-- Eleventh test (upper half active)
		A_32b <= x"FFFF0000";
		B_32b <= x"0000FFFF";

		wait for WAIT_TIME;

		-- Twelfth test (sparse bits)
		A_32b <= x"80000001";
		B_32b <= x"00000001";

		wait for WAIT_TIME;

		wait;
	end process;

end TEST;