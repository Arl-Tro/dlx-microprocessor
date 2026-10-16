library IEEE;
use IEEE.std_logic_1164.all; --  libreria IEEE con definizione tipi standard logic
use WORK.constants.all; -- libreria WORK user-defined

entity MUX21_GENERIC is
generic (NBIT : integer := numBit;
                           DELAY_MUX : time := tp_mux);
port (
        A : in std_logic_vector(NBIT - 1 downto 0);
        B : in std_logic_vector(NBIT - 1 downto 0);
        SEL : in std_logic;
        Y : out std_logic_vector(NBIT - 1 downto 0));

end MUX21_GENERIC;

architecture BEHAVIORAL of MUX21_GENERIC is

begin
process (SEL, A, B)
begin
        if SEL = '1' then

                Y <= A;
        else
                Y <= B;
        end if;
end process;

end BEHAVIORAL;

architecture STRUCTURAL of MUX21_GENERIC is

signal A_select : std_logic_vector (NBIT - 1 downto 0);
signal B_select : std_logic_vector (NBIT - 1 downto 0);
signal SB : std_logic;

component ND2

        port (
                A : in std_logic;
                B : in std_logic;
                Y : out std_logic);
end component;

component IV

        port (
                A : in std_logic;
                Y : out std_logic);
end component;

begin
UIV : IV port map(SEL, SB);

generate_and : for i in 0 to NBIT - 1 generate

        AND_A : ND2 port map(A(i), SEL, A_select(i));
        AND_B : ND2 port map(B(i), SB, B_select(i));
end generate;

generate_or : for i in 0 to NBIT - 1 generate
        OUT_D : ND2 port map(A_select(i), B_select(i), Y(i));

end generate;

end STRUCTURAL;

configuration CFG_MUX21_GEN_BEHAVIORAL of MUX21_GENERIC is
for BEHAVIORAL
end for;
end CFG_MUX21_GEN_BEHAVIORAL;

configuration CFG_MUX21_GEN_STRUCTURAL of MUX21_GENERIC is
for STRUCTURAL
        for all : IV
                use configuration WORK.CFG_IV_BEHAVIORAL;
        end for;
        for all : ND2
                use configuration WORK.CFG_ND2_ARCH2;
        end for;
end for;
end CFG_MUX21_GEN_STRUCTURAL;