library IEEE;
use ieee.std_logic_1164.all;
use WORK.constants.all;

entity REG_PIPE is
	generic(
		NBIT : integer := numBit);
	port(
		CLK : in std_logic;
		RST : in std_logic;
		EN  : in std_logic;
		D   : in std_logic_vector(NBIT-1 downto 0);
		Q   : out std_logic_vector(NBIT-1 downto 0)
	);
end entity;

architecture BEHAVIORAL of REG_PIPE is
begin
	process(CLK, RST)
	begin
		if RST = '0' then
			Q <= (others => '0');
		elsif rising_edge(CLK) then
			if EN = '1' then
				Q <= D;
			end if;
		end if;
	end process;
end architecture;
