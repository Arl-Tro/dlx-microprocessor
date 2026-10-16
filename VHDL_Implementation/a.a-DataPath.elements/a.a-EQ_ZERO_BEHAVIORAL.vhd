library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
use ieee.std_logic_arith.all;
use work.myTypes.all;

entity EQ_ZERO_BEHAVIORAL is
    generic (
        NBIT : natural := 32
    );
    port (
        D : in std_logic_vector (NBIT - 1 downto 0); -- Input data
        EZ : out std_logic -- Will be '1' if D is 0 or '0' if it is not (Equal Zero)
    );
end entity;

architecture BEHAVIORAL of EQ_ZERO_BEHAVIORAL is
       constant ZERO : std_logic_vector (NBIT - 1 downto 0) := (others => '0');
begin
    process (D) is
    begin
        if D = ZERO then 
            EZ <= '1';
        else
            EZ <= '0';
        end if;
    end process;
end architecture;