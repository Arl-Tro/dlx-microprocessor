library IEEE;
use ieee.std_logic_1164.all;
use WORK.constants.all;
use ieee.numeric_std.all;

entity SIGN_EXTENSION is
    port(
        DATA_IN : in std_logic_vector(4 downto 0);
        DATA_OUT : out std_logic_vector(31 downto 0)
    );
end entity SIGN_EXTENSION;

architecture BHV of SIGN_EXTENSION is
    signal SIGN_BIT : std_logic; 
    begin
        SIGN_BIT <= DATA_IN(4);
        DATA_OUT <= (31 downto 5 => SIGN_BIT) & DATA_IN(4 downto 0);

end architecture BHV;


