library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity MUX_61_GEN is
    generic (
        N : integer := 8
    );
    port (
        I0  : in  std_logic_vector(N-1 downto 0);
        I1  : in  std_logic_vector(N-1 downto 0);
        I2  : in  std_logic_vector(N-1 downto 0);
        I3  : in  std_logic_vector(N-1 downto 0);
        I4  : in  std_logic_vector(N-1 downto 0);
	I5  : in  std_logic_vector(N-1 downto 0);
        SEL : in  std_logic_vector(2 downto 0);
        Y   : out std_logic_vector(N-1 downto 0)
    );
end entity MUX_61_GEN;


architecture Behavioral of MUX_61_GEN is
begin

    process(I0, I1, I2, I3, I4, I5,  SEL)
    begin
        case SEL is
            when "000" => Y <= I0;
            when "001" => Y <= I1;
            when "010" => Y <= I2;
            when "011" => Y <= I3;
            when "100" => Y <= I4;
	    when "101" => Y <= I5;
            when others => Y <= (others => '0');
        end case;
    end process;

end architecture Behavioral;
