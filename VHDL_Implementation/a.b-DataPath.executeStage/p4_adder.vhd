library IEEE;
use IEEE.std_logic_1164.all;
use WORK.constants.all;

entity P4_ADDER is
    generic (
        NBIT : integer := 32);
    port (
        A : in std_logic_vector(NBIT - 1 downto 0);
        B : in std_logic_vector(NBIT - 1 downto 0);
        Cin : in std_logic;
        S : out std_logic_vector(NBIT - 1 downto 0);
        Cout : out std_logic);
end entity;

architecture STRUCTURAL of P4_ADDER is

    -- Constants
    constant NBLOCKS : integer := NBIT / numBit_block;

    -- Signals
    signal GeneratedCarry : std_logic_vector(NBLOCKS downto 0); -- Add one more bit, bit0 is carry in, bit1 is carry for bit 4 etc, bit NBLOCK is used for carry out
    signal B_xored : std_logic_vector(NBIT-1 downto 0);
    -- Components
    component CARRY_GENERATOR is
        generic (
            NBIT : integer := NBIT;
            NBIT_PER_BLOCK : integer := numBit_block
        );
        port (
            A : in std_logic_vector(NBIT - 1 downto 0);
            B : in std_logic_vector(NBIT - 1 downto 0);
            Cin : in std_logic;
            Co : out std_logic_vector((NBIT / NBIT_PER_BLOCK) - 1 downto 0) -- Vector of the calculated carrys
        );
    end component;

    component SUM_GENERATOR is
        generic (
            NBIT : integer := numBit;
            NBLOCKS : integer := NBLOCKS);
        port (
            A : in std_logic_vector(NBIT - 1 downto 0);
            B : in std_logic_vector(NBIT - 1 downto 0);
            Cin : in std_logic_vector(NBLOCKS - 1 downto 0);
            S : out std_logic_vector(NBIT - 1 downto 0)
        );
    end component;

    component XOR_2 
		port(
			A : in std_logic;
			B : in std_logic;
			Y : out std_logic
		);
	end component;

begin

	XOR_LAYER_0 : for j in 0 to NBIT-1 generate
		XOR_INST_0: XOR_2
			port map(
				A => B(j),
				B => Cin,
				Y => B_xored(j)
			);	
	end generate XOR_LAYER_0;

    CARRY_GEN : CARRY_GENERATOR port map(
        A => A,
        B => B_xored,
        Cin => Cin,
        Co => GeneratedCarry(NBLOCKS downto 1) -- leave GeneratedCarry(0) unassigned
    );

    GeneratedCarry(0) <= Cin; -- Assign carry in to generated carry 0
    Cout <= GeneratedCarry(NBLOCKS - 1); -- Assign the carry out

    SUM_GEN : SUM_GENERATOR port map(
        A => A,
        B => B_xored,
        Cin => GeneratedCarry(NBLOCKS - 1 downto 0), -- pass the carry in to first block, leave last carry generated signal out (only used in carry out)
        S => S
    );

end architecture;

configuration CFG_P4_ADDER of P4_ADDER is
    for STRUCTURAL

        for all : CARRY_GENERATOR
            use configuration WORK.CFG_CARRY_GENERATOR_STRUCTURAL;
        end for;

        for all : SUM_GENERATOR
            use configuration WORK.CFG_SUM_GENERATOR_STRUCTURAL;
        end for;

    end for;
end configuration CFG_P4_ADDER;