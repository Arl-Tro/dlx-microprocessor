library ieee;
use ieee.std_logic_1164.all;

use work.myTypes.all;

entity MUX21 is
    generic (
        NBIT : natural := 32
    );
    port (
        A, B : in std_logic_vector (NBIT - 1 downto 0); -- A is output when SEL is 0, B is output when SEL is 1
        Q : out std_logic_vector (NBIT - 1 downto 0);
        SEL : in std_logic
    );
end entity;

architecture BEHAVIORAL of MUX21 is

begin

    process (A, B, SEL)
    begin
        if SEL = '0' then  
            Q <= A;
        else 
            Q <= B;
        end if;
    end process;

end architecture;