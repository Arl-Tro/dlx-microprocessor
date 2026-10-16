library IEEE;
use IEEE.std_logic_1164.all;
use WORK.constants.all;

entity XOR_2 is
	port(
		A : in std_logic;
		B : in std_logic;
		Y : out std_logic
	);
end entity;

architecture BHV of XOR_2 is
  begin
	Y <= A xor B;
end architecture;
