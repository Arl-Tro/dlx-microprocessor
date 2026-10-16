library IEEE;
use IEEE.std_logic_1164.all; --  libreria IEEE con definizione tipi standard logic
use WORK.constants.all; 

entity LSL is
	generic(NBIT: integer :=numBit);
	port(
		A : in std_logic_vector(NBIT-1 downto 0);
		Y : out std_logic_vector(NBIT-1 downto 0)
	);
end entity;

architecture WIRED of LSL is
begin 
	Y <= A(NBIT-2 downto 0) & '0';
end architecture;
