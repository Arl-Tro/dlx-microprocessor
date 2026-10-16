library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity INV is
    port (
        A : in  STD_LOGIC;
        Y : out STD_LOGIC
    );
end INV;

architecture Behavioral of INV is
begin

    Y <= not A ;

end Behavioral;