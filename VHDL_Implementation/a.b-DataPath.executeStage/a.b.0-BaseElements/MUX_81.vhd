library IEEE;
use ieee.std_logic_1164.all;
use WORK.constants.all;

entity MUX_81 is
    generic(
        NBIT : integer :=numbit);
    port(
        D0, D1, D2, D3, D4, D5, D6, D7 : in std_logic_vector(NBIT-1 downto 0);
        SEL : in std_logic_vector(2 downto 0);
        Z : out std_logic_vector(NBIT-1 downto 0)
    );
end entity;

architecture BHV of MUX_81 is
begin
    process(D0,D1,D2,D3,D4,D5,D6,D7, SEL)
        begin
        case (SEL) is
            when "000" =>
                Z <= D0;
            when "001" =>
                Z <= D1;
            when "010" =>
                Z <= D2;
            when "011" =>
                Z <= D3;
            when "100" =>
                Z <= D4;
            when "101" =>
                Z <= D5;
            when "110" =>
                Z <= D6;
            when "111" =>
                Z <= D7;    
            when others =>
                Z <= (others => '0');
        end case;
    end process;
end architecture;

