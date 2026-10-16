library IEEE;
use IEEE.std_logic_1164.all; --  libreria IEEE con definizione tipi standard logic
use WORK.constants.all; 

entity MUX31_GENERIC is
generic (NBIT : integer := numBit;
                           DELAY_MUX : time := tp_mux);
port (
        A : in std_logic_vector(NBIT - 1 downto 0);
        B : in std_logic_vector(NBIT - 1 downto 0);
        C : in std_logic_vector(NBIT - 1 downto 0);
        SEL : in std_logic_vector(1 downto 0);
        Y : out std_logic_vector(NBIT - 1 downto 0));

end MUX31_GENERIC;

architecture BEHAVIORAL of MUX31_GENERIC is

begin
	process (SEL, A, B, C)
		begin
        	case SEL is
            		when "00" =>
               			Y <= A;
            		when "01" =>
                		Y <= B;
            		when "10" =>
                		Y <= C;
            		when others =>
                		Y <= (others => '0'); 
        	end case;
	end process;

end BEHAVIORAL;


