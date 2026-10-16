library IEEE;
use ieee.std_logic_1164.all;
use WORK.constants.all;

entity MUX_41 is
    generic(
        NBIT : integer :=numbit);
    port(
        D0, D1, D2, D3 : in std_logic_vector(NBIT-1 downto 0);
        SEL : in std_logic_vector(1 downto 0);
        Z : out std_logic_vector(NBIT-1 downto 0)
    );
end entity;

architecture BHV of MUX_41 is
begin
    process(D0,D1,D2,D3, SEL)
        begin
        case (SEL) is
            when "00" =>
                Z <= D0;
            when "01" =>
                Z <= D1;
            when "10" =>
                Z <= D2;
            when "11" =>
                Z <= D3;
            when others =>
                Z <= (others => '0');
        end case;
    end process;
end architecture;

