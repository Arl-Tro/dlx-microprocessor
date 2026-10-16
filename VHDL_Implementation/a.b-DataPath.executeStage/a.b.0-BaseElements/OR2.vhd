library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity OR2 is
    port (
        A : in  STD_LOGIC;
        B : in  STD_LOGIC;
        Y : out STD_LOGIC
    );
end OR2;

architecture Behavioral of OR2 is
begin

    Y <= A or B;

end Behavioral;