library IEEE;
use IEEE.std_logic_1164.all; --  libreria IEEE con definizione tipi standard logic
use WORK.constants.all; 

entity encoder is
	port(
		S_IN : 	in std_logic_vector(2 downto 0);
		MAG  :	out std_logic_vector(1 downto 0);
		SIGN :	out std_logic	
	);
end entity;

architecture BEHAVIORAL of encoder is
begin 
process (S_IN)
	begin 
	case S_IN is
		when "001" =>
			MAG <= "01";
			SIGN <= '0';
		when "010" =>
			MAG <= "01";
			SIGN <= '0';
		when "011" =>
			MAG <= "10";
			SIGN <= '0';
		when "100" =>
			MAG <= "10";
			SIGN <= '1';
		when "101" =>
			MAG <= "01";
			SIGN <= '1';
		when "110" =>
			MAG <= "01";
			SIGN <= '1';
		when others =>
			MAG <= "00";
			SIGN <= '0';
	end case;
end process;
end architecture BEHAVIORAL;
