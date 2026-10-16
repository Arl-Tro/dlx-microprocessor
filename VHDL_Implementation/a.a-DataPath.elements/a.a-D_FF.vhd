library ieee;
use ieee.std_logic_1164.all;

use work.myTypes.all;

entity D_FF is
    port (
        D : in std_logic; -- Input data
        Q : out std_logic; -- Output data
        CLK, EN, NRST : in std_logic -- Control signals: clock(active high), enable(active high), reset (active low). All are clock synchronous
    );
end entity;

architecture BEHAVIORAL of D_FF is

begin

    process (CLK) is
    begin
        -- Only run on rising edge of the clock
        if rising_edge(CLK) then
            -- Reset takes priority over other inputs
            if NRST = '0' then
                Q <= '0';
            else
                -- Check the enable signal
                if EN = '1' then
                    Q <= D;
                end if;
            end if;
        end if;

    end process;

end architecture;