library IEEE;
use ieee.std_logic_1164.all;

entity DECODER_41 is
    
    port (
        SEL : in std_logic_vector(1 downto 0);
        D0, D1, D2, D3 : out std_logic
    );
end entity;

architecture BHV of DECODER_41 is
begin
    process (SEL)
    begin
        case (SEL) is
            when "00" =>
                D0 <= '1';
                D1 <= '0';
                D2 <= '0';
                D3 <= '0';
            when "01" =>
                D0 <= '0';
                D1 <= '1';
                D2 <= '0';
                D3 <= '0';
            when "10" =>
                D0 <= '0';
                D1 <= '0';
                D2 <= '1';
                D3 <= '0';
            when "11" =>
                D0 <= '0';
                D1 <= '0';
                D2 <= '0';
                D3 <= '1';
            when others =>
                D0 <= '0';
                D1 <= '0';
                D2 <= '0';
                D3 <= '0';
        end case;
    end process;
end architecture;