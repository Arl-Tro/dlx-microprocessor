library IEEE;
use ieee.std_logic_1164.all;
use WORK.constants.all;
use ieee.numeric_std.all;

entity BIT_REVERSER is
    Generic (
        NBIT : integer := 64 
    );
    Port (
        data_in  : in  std_logic_vector(NBIT-1 downto 0);
        LR : in std_logic;
        data_out : out std_logic_vector(NBIT-1 downto 0)
    );
end entity BIT_REVERSER;

architecture Behavioral of BIT_REVERSER is
begin

    GEN_REV: for i in 0 to NBIT-1 generate
        data_out(i) <= data_in((NBIT-1) - i) when LR = '0' else data_in(i);
    end generate GEN_REV;

end architecture Behavioral;