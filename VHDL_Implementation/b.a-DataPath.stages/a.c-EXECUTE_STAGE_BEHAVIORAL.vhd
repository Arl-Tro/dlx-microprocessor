library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.myTypes.all;
use work.cpu_32b_types.all;

-- Fetch Stage implementation

entity EXECUTE_STAGE_BEHAVIORAL is
    generic (
        NBIT : natural := 32;
        NBIT_IDX : natural := 5 -- Number of bits used to select a signle register, also determines the number of registers

    );

    port (
        -- Global
        CLK : in std_logic;
        NRST : in std_logic; -- Reset, activelow
        EN_STAGE : in std_logic; -- Stage enable signal

        -- Execute stage, control
        EXECUTE_CTRL : in ex_ctrl_in_t;
        alu_out : buffer std_logic_vector(NBIT - 1 downto 0); -- From alu out to out reg

        -- Execute stage, data
        EXECUTE_DIN : in ex_data_in_t;
        EXECUTE_DOUT : out ex_data_out_t

    );
end EXECUTE_STAGE_BEHAVIORAL;

architecture STRUCTURAL of EXECUTE_STAGE_BEHAVIORAL is

    
    -- Component declarations

    component REG is
        generic (
            NBIT : natural := NBIT
        );
        port (
            D : in std_logic_vector (NBIT - 1 downto 0); -- Input data
            Q : out std_logic_vector (NBIT - 1 downto 0); -- Output data
            CLK, EN, NRST : in std_logic -- Control signals: clock(active high), enable(active high), reset (active low). All are clock synchronous
        );
    end component;

    component MUX21 is
        generic (
            NBIT : natural := NBIT
        );
        port (
            A, B : in std_logic_vector (NBIT - 1 downto 0); -- A is output when SEL is 0, B is output when SEL is 1
            Q : out std_logic_vector (NBIT - 1 downto 0);
            SEL : in std_logic
        );
    end component;

    component ALU_BEHAVIORAL is
        generic (
            NBIT : natural := NBIT
        );
        port (
            A, B : in std_logic_vector(NBIT - 1 downto 0); -- Input operands
            CMD : in aluOp; -- Alu operation selection
            Q : out std_logic_vector(NBIT - 1 downto 0) -- Output
        );
    end component;

    component EQ_ZERO_BEHAVIORAL is
        generic (
            NBIT : natural := 32
        );
        port (
            D : in std_logic_vector (NBIT - 1 downto 0); -- Input data
            EZ : out std_logic -- Will be '1' if D is 0 or '0' if it is not (Equal Zero)
        );
    end component;

    component BRANCH_SELECTOR is generic (
        NBIT : natural := 32
        );
        port (
            BRANCH_MODE : in branchSelection_t; -- Input to select the branch condition 
            EQ_ZERO_RSLT : in std_logic; -- Input from the zero comparator to use for conditional branches (if this signal is high the input is assumed to be 0)

            BRANCH_SEL : out std_logic -- Output to be sent to the branch selection MUX. It will be 0 for taking the NPC form the decode stage or 1 for taking the NPC from the ALU result
        );

    end component;

    -- Signals
    signal nrst_final : std_logic; -- NRST signal made by the AND (reset if either the global or control reset signals are active) of the global and control resets
    signal en_raluout : std_logic; -- Enable signal ANDed with EN_STAGE
    -- Execute stage
    signal operand_a, operand_b : std_logic_vector(NBIT - 1 downto 0); -- Operands going to the ALU
    signal zero_flag : std_logic; -- Flag from the zero comparator for conditional branching
    signal branch_select : std_logic := '0'; -- Signal which is the AND of zero_flag and bez_en from the CU, to be connected to the mux that selects the NPC
        signal alu_to_out : std_logic_vector(NBIT -1 downto 0); -- Connect Q from ALU to ALU_OUT
    signal npc_alu_out : std_logic_vector(NBIT - 1 downto 0); -- Either alu_out or npc input depending on the branch condition
    signal npc_addr_mux_out : std_logic_vector(NBIT_IDX - 1 downto 0); -- Select the input npc or R31 for jump and link operations
    constant link_reg : std_logic_vector(NBIT_IDX - 1 downto 0) := std_logic_vector(to_unsigned(31, NBIT_IDX)); -- Register 31 is the standard link register
begin
    nrst_final <= NRST and EXECUTE_CTRL.NRST_STAGE;
    en_raluout <= EN_STAGE and EXECUTE_CTRL.EN_RALUOUT;
    -----------------------------------------------------------------
    --                      EXECUTE STAGE                          --
    -----------------------------------------------------------------

    -- ALU operands & registers
    MUX_A : component MUX21 port map(EXECUTE_DIN.NPC_IN, EXECUTE_DIN.RS1_DATA, operand_a, EXECUTE_CTRL.MUX_A_SEL);
    MUX_B : component MUX21 port map(EXECUTE_DIN.RS2_DATA, EXECUTE_DIN.RIMM_DATA, operand_b, EXECUTE_CTRL.MUX_B_SEL);

    ALU_CMP : component ALU_BEHAVIORAL port map(
        A => operand_a,
        B => operand_b,
        CMD => EXECUTE_CTRL.ALU_OP,
        Q => alu_to_out
        -- Execute stage output signals
    );
    alu_out <= alu_to_out;

    MUX_ALU_OUT : component MUX21 port map(alu_out, EXECUTE_DIN.NPC_IN, npc_alu_out,  EXECUTE_CTRL.LINK_EN); -- On a branch&link instruction, take the input NPC and move it to ALU_OUT so that it can be used for link during jumps (it propagates the insturction's NPC to the writeback stage so that it can be written to R31)

    ALU_OUT_REG : component REG port map(npc_alu_out, EXECUTE_DOUT.ALU_DATA, CLK, en_raluout, nrst_final);

    -- Conditional branching
    ZERO_CHK : component EQ_ZERO_BEHAVIORAL port map(EXECUTE_DIN.RS1_DATA, zero_flag);

    BRANCH_SEL : component BRANCH_SELECTOR port map(
        BRANCH_MODE => EXECUTE_CTRL.BRANCH_MODE,
        EQ_ZERO_RSLT => zero_flag,
        BRANCH_SEL => branch_select
    );

    -- Branch signal gets registered in the CU
    EXECUTE_DOUT.BRANCH <= branch_select;
    MUX_ALU_NPC : component MUX21 port map(EXECUTE_DIN.NPC_IN, alu_out, EXECUTE_DOUT.NPC_OUT, branch_select); -- Select either the "standard" NPC from decode stage (PC + 1) or the ALU out (PC + IMM_SHORT) for conditional branch

    MUX_NPC : component MUX21 generic map (NBIT => NBIT_IDX) port map(EXECUTE_DIN.RD_ADDR_IN, link_reg, npc_addr_mux_out, EXECUTE_CTRL.LINK_EN); -- Select either the "standard" NPC from decode stage (PC + 1) or the ALU out (PC + IMM_SHORT) for conditional branch

    -- NPC_REG : component REG port map(npc_mux_out, EXECUTE_DOUT.NPC_OUT, CLK, EN_STAGE, nrst_final);

    -- Propagate ram_data, RD and NPC
    REG_WADDR_PROP_EXE : entity work.REG
        generic map(
            NBIT => NBIT_IDX
        )
        port map(
            D => npc_addr_mux_out,
            Q => EXECUTE_DOUT.RD_ADDR_OUT,
            CLK => CLK,
            EN => EN_STAGE,
            NRST => nrst_final
        );

    REG_RAMDATA_PROP_EXE : REG port map(EXECUTE_DIN.RS2_DATA, EXECUTE_DOUT.RAM_DATA, CLK, EN_STAGE, nrst_final);
end STRUCTURAL;