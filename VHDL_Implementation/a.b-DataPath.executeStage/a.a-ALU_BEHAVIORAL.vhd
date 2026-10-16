library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
use ieee.std_logic_arith.all;
use work.myTypes.all;

entity ALU_BEHAVIORAL is
    generic (
        NBIT : natural := 32
    );
    port (
        A, B : in std_logic_vector(NBIT - 1 downto 0); -- Input operands
        CMD : in aluOp; -- Alu operation selection
        Q : out std_logic_vector(NBIT - 1 downto 0) -- Output
    );
end entity;

architecture BEHAVIORAL of ALU_BEHAVIORAL is
    signal Asign, Bsign, Qsign : signed (NBIT - 1 downto 0);
begin

    Asign <= signed(A);
    Bsign <= signed(B);
    Q <= std_logic_vector(Qsign);

    process (Asign, Bsign, CMD)
    begin
        case CMD is
            when NOP => Qsign <= (others => '0');
            when ADD => Qsign <= Asign + Bsign;
            when SUB => Qsign <= Asign - Bsign;
            when others =>
                Qsign <= (others => '0'); -- Catches other aluOp enum values and meta-values

        end case;

    end process;

end architecture;