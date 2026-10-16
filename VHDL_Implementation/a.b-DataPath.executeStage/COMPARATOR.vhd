library IEEE;
use ieee.std_logic_1164.all;
use WORK.constants.all;
use ieee.numeric_std.all;

-- This entity implements a comparator that checks these conditions :
-- equal , greater, lower , greater or equal, lower or equal 

entity COMPARATOR is
    port (
        A        : in std_logic_vector(31 downto 0);
        B        : in std_logic_vector(31 downto 0);
        SEL      : in std_logic_vector(2 downto 0);
        SIGNED_OP: in std_logic;   -- '1' = signed comparison (sge/slt...), '0' = unsigned (sgeu/sltu...)
        COMP     : out std_logic_vector(31 downto 0)
    );
end entity;

-- PORTS EXPLANATION

-- A, B --> inputs to be compared
-- SEL --> selection signal used by the output MUX; it comes from the ALU encoder
-- SIGNED_OP --> selects signed vs unsigned interpretation for l/leq/g/geq (eq is unaffected)
-- COMP --> result of the comparison, zero-extended to 32 bit (bit 0 = result, bits 31 downto 1 = '0')
--          so that it matches the width of the ALU output mux

architecture Structural of COMPARATOR is
    -- COMPONENTS DEFINITION

    component NOR_NBIT 
            generic (
                NBIT : integer := 4
            );
            port (
                A : in  STD_LOGIC_VECTOR(NBIT-1 downto 0);
                Y : out STD_LOGIC
            );

    end component;

    component CARRY_SEL_ADD
        generic(NBIT : integer := numBit;
		    NBLOCKS : integer := numBit/numBit_block);
	    port(
		    A : in std_logic_vector(NBIT-1 downto 0);
		    B : in std_logic_vector(NBIT-1 downto 0);
		    Ci : in std_logic;
		    S : out std_logic_vector(NBIT-1 downto 0);
		    Co : out std_logic
	    );
    end component;

    component MUX_61_GEN
        generic (
            N : integer := 8
        );
        port (
            I0  : in  std_logic_vector(N-1 downto 0);
            I1  : in  std_logic_vector(N-1 downto 0);
            I2  : in  std_logic_vector(N-1 downto 0);
            I3  : in  std_logic_vector(N-1 downto 0);
            I4  : in  std_logic_vector(N-1 downto 0);
	    I5  : in  std_logic_vector(N-1 downto 0);
            SEL : in  std_logic_vector(2 downto 0);
            Y   : out std_logic_vector(N-1 downto 0)
    );
    end component;

    component XOR_2
        port(
            A : in std_logic;
            B : in std_logic;
            Y : out std_logic
        );
    end component;

    -- SIGNALS DEFINITION 
    -- NB : some signals are in vectorial form '0 downto 0'(even though they have 1 bit) to match the components generic description
    signal COUT : std_logic;    -- Carry out signal of the ADD/SUB
    signal SUM  : std_logic_vector(31 downto 0);       -- Output SUM of the ADD/SUB
    signal Z    : std_logic;    -- NOR of the SUM bits
    signal eq, ne, leq, g , geq , l : std_logic_vector(0 downto 0);    -- equal, not equal, lower or equal, greater , greater or equal , lower
    signal B_NEG : std_logic_vector(31 downto 0);
    signal MUX_OUT : std_logic_vector(0 downto 0);
    signal OVERFLOW    : std_logic;    -- signed overflow of the A + B_NEG + 1 operation
    signal LT_UNSIGNED : std_logic;    -- A < B, unsigned criterion (based on COUT)
    signal LT_SIGNED   : std_logic;    -- A < B, signed criterion (based on sign of result and overflow)
    signal LT           : std_logic;   -- selected A < B, depending on SIGNED_OP
    begin
    -- For a comparator with inputs A and B, we need to perform A-B. For this reason set the carry in of the adder = 1, and the we need to include an XOR layer
    B_NEGATION : for i in 0 to 31 generate
		XOR_INST_0: XOR_2
			port map(
				A => B(i),
				B => '1',
				Y => B_NEG(i)
			);	
	end generate B_NEGATION;
		
    ADDER : CARRY_SEL_ADD 
        generic map(
            NBIT => 32,
            NBLOCKS => 8
        )
        port map(
				A => A,
				B => B_NEG,
				Ci => '1',
				S => SUM,
				Co => COUT
			);
    
    NOR_BIT : NOR_NBIT
        generic map(
            NBIT => 32
        )
        port map(
            A => SUM,
            Y => Z
        );

    -- Correct Signed Overflow:
    -- Overflow occurs when operands A and B_NEG have the SAME sign (not XOR),
    -- but the result SUM has a DIFFERENT sign (XOR).
    OVERFLOW <= (not (A(31) xor B_NEG(31))) and (A(31) xor SUM(31));

    
    -- A < B, unsigned criterion: no borrow occurred (see COUT/NOR block above)
    LT_UNSIGNED <= not(COUT);
    -- A < B, signed criterion: result is negative, corrected for overflow
    LT_SIGNED   <= SUM(31) xor OVERFLOW;
    -- Select which criterion feeds the comparisons below
    LT <= LT_SIGNED when SIGNED_OP = '1' else LT_UNSIGNED;

    -- A=B  (sign-independent)
    eq(0) <= Z;
    -- A!=B
    ne(0) <= not(Z);
    -- A<=B
    leq(0) <= LT or Z;
    -- A>B 
    g(0) <= not(Z) and not(LT);
    -- A >=B 
    geq(0) <= not(LT);
    -- A<B 
    l(0) <= LT;
    -- MULTIPLEXING BASED ON THE REQUESTED COMPARISON
    OUT_MUX : MUX_61_GEN
        generic map(
            N => 1
        )
        port map(
            I0 => eq,  
            I1 => l,
            I2 => leq,
            I3 => g,
            I4 => geq,
	    I5 => ne,
            SEL => SEL,
            Y => MUX_OUT
    );

    -- Zero-extend the 1-bit comparison result to 32 bit, so COMP has the
    -- same width as the other ALU units (adder, multiplier) feeding the
    -- final output mux
    COMP(0) <= MUX_OUT(0);
    COMP(31 downto 1) <= (others => '0');

end architecture Structural;
