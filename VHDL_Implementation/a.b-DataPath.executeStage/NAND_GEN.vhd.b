library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity nand_gate_nbit is
    generic (
        NBITS : integer := 4  -- Numero di ingressi (predefinito a 4)
    );
    port (
        A : in  std_logic_vector(NBITS - 1 downto 0);
        Y : out std_logic
    );
end entity nand_gate_nbit;

architecture Behavioral of nand_gate_nbit is
begin
    -- AND riduttiva su tutti i bit del vettore 'a', seguita dalla negazione NOT
    Y <= not (and A);
end architecture Behavioral;