library IEEE;
use ieee.std_logic_1164.all;
use WORK.constants.all;
use ieee.numeric_std.all;

-- This entity implements a 32 bits T2-like shifter, composed of 3 levels:
-- The first level is the mask generation stage;
-- The second level is a coarse-grain shift(implemented using a 4_to_1 MUX to select the correct mask) ;
-- The third level is the fine-grain shift(implemented using a 8_to_1 MUX);

entity SHIFTER_T2 is
    port (
        REG1 : in std_logic_vector(31 downto 0);
        REG2 : in std_logic_vector(31 downto 0);
        CONFIG : in std_logic_vector(1 downto 0);
        Z : out std_logic_vector(31 downto 0)
    );
end entity;
-- SIGNAL EXPLANATION
-- REG1 --> value to be shifted
-- REG2 --> shift amount (only the low 5 bits are needed)
-- CONFIG --> selects the operation (logical/arithmetical, left/right)
-- Z --> shifted output 

architecture STRUCT of SHIFTER_T2 is

-- COMPONENTS DEFINITION
component MASK_GEN 
    port(
        LR : in std_logic;
        AL : in std_logic;
        R1 : in std_logic_vector(31 downto 0);
        M0, M8, M16, M24 : out std_logic_vector(39 downto 0)
    );
end component;

component MUX_41
    generic(
        NBIT : integer :=numbit);
    port(
        D0, D1, D2, D3 : in std_logic_vector(NBIT-1 downto 0);
        SEL : in std_logic_vector(1 downto 0);
        Z : out std_logic_vector(NBIT-1 downto 0)
    );
end component;

component MUX_81 
    generic(
        NBIT : integer :=numbit);
    port(
        D0, D1, D2, D3, D4, D5, D6, D7 : in std_logic_vector(NBIT-1 downto 0);
        SEL : in std_logic_vector(2 downto 0);
        Z : out std_logic_vector(NBIT-1 downto 0)
    );
end component;

component BIT_REVERSER is
    generic (
        NBIT : integer := 64 
    );
    port (
        data_in  : in  std_logic_vector(NBIT-1 downto 0);
        LR : in std_logic;
        data_out : out std_logic_vector(NBIT-1 downto 0)
    );
end component;

-------------------------------------------------------------------------------------------------------------------------------------------------
-- SIGNALS
signal reg1_reversed : std_logic_vector(31 downto 0); -- Intermediate signal for pre-shift bit reversal
signal mask0, mask8, mask16, mask24 : std_logic_vector(39 downto 0);
signal sh0, sh1, sh2, sh3, sh4, sh5, sh6, sh7 : std_logic_vector(31 downto 0);  -- inputs of the second mux
signal mux_out1 : std_logic_vector(39 downto 0);
signal mux_out2 : std_logic_vector(31 downto 0);
-------------------------------------------------------------------------------------------------------------------------------------------------

begin

-- Pre-reverser: Mirrors the input operand when a Left Shift (LR = '0') is required
FIRST_REV : BIT_REVERSER 
    generic map(NBIT => 32)
    port map(
        data_in  => REG1,
        LR       => CONFIG(0),
        data_out => reg1_reversed
    );

LEVEL1 : MASK_GEN 
    port map (
        LR  => CONFIG(0),
        AL  => CONFIG(1),
        R1  => reg1_reversed, -- Connection of the reversed operand to the mask generator
        M0  => mask0,
        M8  => mask8,
        M16 => mask16,
        M24 => mask24
    );

-------------------------------------------------------------------------------------------------------------------------------------------------

LEVEL2 : MUX_41
    generic map(NBIT => 40)
    port map(
        D0  => mask0,
        D1  => mask8,
        D2  => mask16,
        D3  => mask24,
        SEL => REG2(4 downto 3),
        Z   => mux_out1
    );

-------------------------------------------------------------------------------------------------------------------------------------------------

-- Extracting 32-bit windows directly from the coarse shift output for fine grain selection (0 to 7 bits)
sh0 <= mux_out1(31 downto 0);
sh1 <= mux_out1(32 downto 1);
sh2 <= mux_out1(33 downto 2);
sh3 <= mux_out1(34 downto 3);
sh4 <= mux_out1(35 downto 4);
sh5 <= mux_out1(36 downto 5);
sh6 <= mux_out1(37 downto 6);
sh7 <= mux_out1(38 downto 7);

LEVEL3 : MUX_81
    generic map(NBIT => 32)
    port map(
        D0  => sh0,
        D1  => sh1,
        D2  => sh2,
        D3  => sh3,
        D4  => sh4,
        D5  => sh5,
        D6  => sh6,
        D7  => sh7,
        SEL => REG2(2 downto 0),
        Z   => mux_out2
    );

-------------------------------------------------------------------------------------------------------------------------------------------------

-- Post-reverser: Re-mirrors the final output to restore correct bit ordering for Left Shift
SECOND_REV : BIT_REVERSER 
    generic map(NBIT => 32)
    port map(
        data_in  => mux_out2,
        LR       => CONFIG(0),
        data_out => Z
    );

end architecture;