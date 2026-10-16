library IEEE;
use IEEE.std_logic_1164.all; --  libreria IEEE con definizione tipi standard logic
use WORK.constants.all; 

entity LSL2 is
	generic(NBIT: integer :=2*numBit);
	port(
		A : in std_logic_vector(NBIT-1 downto 0);
		Y : out std_logic_vector(NBIT-1 downto 0)
	);
end entity;

architecture WIRED of LSL2 is
begin 
	Y <= A(NBIT-3 downto 0 ) & "00";
end architecture;
