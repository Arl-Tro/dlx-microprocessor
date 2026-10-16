library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
use ieee.std_logic_arith.all;
use work.myTypes.all;
use WORK.constants.all;

entity ALU_DBG is
    generic (
        NBIT : natural := 32
    );
    port (
        REG_A, REG_B : in std_logic_vector(NBIT - 1 downto 0); -- Input operands
        -- control signals coming from the encoder
        C_MUX_OUT_SEL : in std_logic_vector(1 downto 0);         -- selection signal for the MUX which chooses the output of the correct unit
        C_ADD_CIN : in std_logic;                                -- Carry in of the add/sub (ADD_CIN = '0' --> ADD , ADD_CIN = '1' --> SUB)
        C_LOGIC_SEL : in std_logic_vector (3 downto 0);          -- Selects the correct logical operation
        C_COMP_SEL :  in std_logic_vector (2 downto 0);          -- Selection signal for the comparator
        C_COMP_TYPE : in std_logic;                              -- Signed( = '1') or unsigned ( = '0' )comparison --> it changes only for lower (<) comparison 
        C_SHIFT_CONFIG : in std_logic_vector (1 downto 0);       -- selects direction and type of the shift
        -- Output signal
        ALU_OUT : out std_logic_vector(NBIT - 1 downto 0)      -- Output
    );
end entity;

architecture STRUCTURAL of ALU_DBG is
    --COMPONENTS

    
    component p4_adder
        generic (
            NBIT : integer := 32);
        port (
            A : in std_logic_vector(NBIT - 1 downto 0);
            B : in std_logic_vector(NBIT - 1 downto 0);
            Cin : in std_logic;
            S : out std_logic_vector(NBIT - 1 downto 0);
            Cout : out std_logic);
        end component;

    component COMPARATOR
        port (
            A        : in std_logic_vector(31 downto 0);
            B        : in std_logic_vector(31 downto 0);
            SEL      : in std_logic_vector(2 downto 0);
            SIGNED_OP: in std_logic;   -- '1' = signed comparison (sge/slt...), '0' = unsigned (sgeu/sltu...)
            COMP     : out std_logic_vector(31 downto 0)
        );
    end component;

    component LOGICALS 	
        generic ( 
            NBIT : integer := numBit
		);
	    port(
		    S : in std_logic_vector(3 downto 0);
		    R1 : in std_logic_vector(NBIT-1 downto 0);
		    R2 : in std_logic_vector(NBIT-1 downto 0);
		    LOUT : out std_logic_vector(NBIT-1 downto 0)
	    );
    end component;

    component SHIFTER_T2
        port (
            REG1 : in std_logic_vector(31 downto 0);
            REG2 : in std_logic_vector(31 downto 0);
            CONFIG : in std_logic_vector(1 downto 0);
            Z : out std_logic_vector(31 downto 0)
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

------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    --SIGNALS
    signal MUX_SEL : std_logic_vector (2 downto 0);
    signal ADD_OUT, LOG_OUT, CMP_OUT, SHIFT_OUT : std_logic_vector(NBIT -1 downto 0);

    begin

    ADDER_INST : p4_adder
        generic map(
            NBIT => 32)
        port map(
            A => REG_A,
            B => REG_B,
            Cin => C_ADD_CIN,
            S => ADD_OUT,
            Cout => open
            );
    
    
    LOG_INST : LOGICALS
        generic map( 
            NBIT => 32
		)
	    port map(
		    S => C_LOGIC_SEL,
		    R1 => REG_A,
		    R2 => REG_B,
		    LOUT => LOG_OUT
	    );

    SHIFT_INST : SHIFTER_T2
        port map(
            REG1 => REG_A,
            REG2 => REG_B,
            CONFIG => C_SHIFT_CONFIG,
            Z => SHIFT_OUT
        );

    COMP_INST : COMPARATOR
        port map(
            A => REG_A,
            B => REG_B,
            SEL => C_COMP_SEL,
            SIGNED_OP => C_COMP_TYPE,
            COMP => CMP_OUT
        );
    
    MUX_INST : MUX_41 
        generic map(
            NBIT => 32)
        port map(
            D0 => ADD_OUT,
            D1 => LOG_OUT, 
            D2 => CMP_OUT, 
            D3 => SHIFT_OUT, 
            SEL => C_MUX_OUT_SEL, 
            Z => ALU_OUT
        );
    
end architecture STRUCTURAL;