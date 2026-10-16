library IEEE;
use ieee.std_logic_1164.all;
use WORK.constants.all;
use ieee.numeric_std.all;

entity MASK_GEN is
    port(
        LR : in std_logic; -- '0' = Left, '1' = Right
        AL : in std_logic; -- '0' = Arithmetic, '1' = Logic
        R1 : in std_logic_vector(31 downto 0);
        M0, M8, M16, M24 : out std_logic_vector(39 downto 0)
    );
end entity MASK_GEN;

-- PORT EXPLANATION
-- LR --> Left(0) or Right(1) shift
-- AL --> Arithmetic(0) or Logic(1) shift
-- R1 --> Input operand to be shifted
-- Mi --> Masks generated

architecture BHV of MASK_GEN is
begin
    process(LR, AL, R1)
        variable sign_bit : std_logic;
    begin
        -- BIT EXTENSION:
        -- IF SRA (Right Arithmetic, LR='1' e AL='0'), bit extension R1(31).
        -- Otherwise sign_bit = '0'
        if (LR = '1' and AL = '0') then
            sign_bit := R1(31);
        else
            sign_bit := '0';
        end if;

        M0  <= (39 downto 32 => sign_bit) & R1;
        M8  <= (39 downto 24 => sign_bit) & R1(31 downto 8);
        M16 <= (39 downto 16 => sign_bit) & R1(31 downto 16);
        M24 <= (39 downto 8  => sign_bit) & R1(31 downto 24);

    end process; 
end architecture BHV;