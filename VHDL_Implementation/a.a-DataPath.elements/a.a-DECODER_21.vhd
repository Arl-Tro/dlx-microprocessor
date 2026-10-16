library IEEE;
use ieee.std_logic_1164.all;

entity DECODER_21 is
    
    port (
        SEL : in std_logic;
        D0, D1 : out std_logic
    );
end entity;

architecture BHV of DECODER_21 is
begin
    process (SEL)
    begin
        case (SEL) is
            when '0' =>
                D0 <= '1';
                D1 <= '0';
            when '1' =>
                D0 <= '0';
                D1 <= '1';
            when others =>
                D0 <= '0';
                D1 <= '0';
                
        end case;
    end process;
end architecture;