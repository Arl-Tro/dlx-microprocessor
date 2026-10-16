library ieee;
use ieee.std_logic_1164.all;

use work.myTypes.all;

-- Bit extender component, can implement sign expansion or zero expansion

entity BIT_EXT is
    generic (
        NBIT_OUT : natural := 32; -- How many bits is the output supposed to have
        NBIT_IN : natural := 16 -- How many bits does the input have?
    );
    port (
        D : in std_logic_vector (NBIT_IN - 1 downto 0); -- Input data
        ZERO_SIGN_EXT : in std_logic; -- If 0, the input is zero extended, if 1 the input is sign extended
        EXTENDED : out std_logic_vector (NBIT_OUT - 1 downto 0) -- Output data
    );
end BIT_EXT;

architecture RTL of BIT_EXT is
begin

    ZERO_SIGN_SEL : with ZERO_SIGN_EXT select EXTENDED <=
    (NBIT_OUT - 1 downto NBIT_IN => D(NBIT_IN - 1)) & D when '1',
    (NBIT_OUT - 1 downto NBIT_IN => '0') & D when others; -- By default do zero expansion

    end architecture;