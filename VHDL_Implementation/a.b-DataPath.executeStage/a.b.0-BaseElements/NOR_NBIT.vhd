library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity NOR_NBIT is
    generic (
        NBIT : integer := 4
    );
    port (
        A : in  STD_LOGIC_VECTOR(NBIT-1 downto 0);
        Y : out STD_LOGIC
    );
end NOR_NBIT;

architecture Structural of NOR_NBIT is
    signal temp : STD_LOGIC_VECTOR(NBIT downto 0);
begin

    temp(0) <= '0';

    GEN_NOR : for i in 0 to NBIT-1 generate
        temp(i+1) <= temp(i) or A(i);
    end generate;

    Y <= not temp(NBIT);

end Structural;