library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.myTypes.all;
use work.cpu_32b_types.all;
use WORK.constants.all;
-- Fetch Stage implementation

entity EXECUTE_STAGE is
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

        -- Execute stage, data
        EXECUTE_DIN : in ex_data_in_t;
        EXECUTE_DOUT : out ex_data_out_t;
        ALU_OUT : out std_logic_vector(NBIT - 1 downto 0);

        -- signals related to the control of the multiplier
        MUL_DONE : out std_logic;
        MUL_BUSY : out std_logic;
        MUX_UNIT_SEL : in std_logic;

        -- Forward unit connection
        RS1_FWD_DATA, RS2_FWD_DATA : in std_logic_vector (NBIT - 1 downto 0); -- Data in, when FWD_EN is high, this repalces the content of the register file for the relative operator registr (rs1 or rs2)
        RS1_FWD_EN, RS2_FWD_EN : in std_logic

    );
end EXECUTE_STAGE;

architecture STRUCTURAL of EXECUTE_STAGE is

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

    component ALU_DBG is
        generic (
            NBIT : natural := 32
        );
        port (
            REG_A, REG_B : in std_logic_vector(NBIT - 1 downto 0); -- Input operands
            -- control signals coming from the encoder
            C_MUX_OUT_SEL : in std_logic_vector(1 downto 0); -- selection signal for the MUX which chooses the output of the correct unit
            C_ADD_CIN : in std_logic; -- Carry in of the add/sub (ADD_CIN = '0' --> ADD , ADD_CIN = '1' --> SUB)
            C_LOGIC_SEL : in std_logic_vector (3 downto 0); -- Selects the correct logical operation
            C_COMP_SEL : in std_logic_vector (2 downto 0); -- Selection signal for the comparator
            C_COMP_TYPE : in std_logic; -- Signed( = '1') or unsigned ( = '0' )comparison --> it changes only for lower (<) comparison 
            C_SHIFT_CONFIG : in std_logic_vector (1 downto 0); -- selects direction and type of the shift
            -- Output signal
            ALU_OUT : out std_logic_vector(NBIT - 1 downto 0) -- Output
        );
    end component;

    component EQ_ZERO is
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

    component ALU_ENCODER
        port (
            CMD : in aluOp;
            MUX_OUT_SEL : out std_logic_vector(1 downto 0); -- selection signal for the MUX which chooses the output of the correct unit
            MULT_EN : out std_logic; -- Enables the Pipe registers of the Multiplier
            ADD_CIN : out std_logic; -- Carry in of the add/sub (ADD_CIN = '0' --> ADD , ADD_CIN = '1' --> SUB)
            LOGIC_SEL : out std_logic_vector (3 downto 0); -- Selects the correct logical operation
            COMP_SEL : out std_logic_vector (2 downto 0); -- Selection signal for the comparator
            COMP_TYPE : out std_logic; -- Signed( = '1') or unsigned ( = '0' )comparison --> it changes only for lower (<) comparison 
            SHIFT_CONFIG : out std_logic_vector (1 downto 0) -- selects direction and type of the shift
        );
    end component;

    component BOOTHMUL_pipelined
        generic (
            NBIT : integer := numBit);
        port (
            CLK : in std_logic;
            RST : in std_logic; -- asynchronous reset, active low
            EN : in std_logic; -- global pipeline enable / stall
            A : in std_logic_vector(NBIT - 1 downto 0);
            B : in std_logic_vector(NBIT - 1 downto 0);
            RES : out std_logic_vector(NBIT - 1 downto 0);

            START : in std_logic; -- 1-cycle pulse: new MUL entering the pipeline
            BUSY : out std_logic; -- high while a multiplication is in flight
            DONE : out std_logic -- 1-cycle pulse: RES is valid this cycle
        );
    end component;
    -- Signals
    signal nrst_final : std_logic; -- NRST signal made by the AND (reset if either the global or control reset signals are active) of the global and control resets
    signal en_raluout : std_logic; -- Enable signal ANDed with EN_STAGE
    -- Execute stage
    signal operand_a, operand_b : std_logic_vector(NBIT - 1 downto 0); -- Operands going to the ALU
    signal zero_flag : std_logic; -- Flag from the zero comparator for conditional branching
    signal branch_select : std_logic := '0'; -- Signal which is the AND of zero_flag and bez_en from the CU, to be connected to the mux that selects the NPC
    signal npc_mux_out : std_logic_vector(NBIT - 1 downto 0); -- Selected NPC value before the registered output stage

    -- control signals from the encoder to the units
    signal S_MUX_OUT_SEL : std_logic_vector(1 downto 0); -- selection signal for the MUX which chooses the output of the correct unit
    signal S_MULT_EN : std_logic; -- Enables the Pipe registers of the Multiplier
    signal S_ADD_CIN : std_logic; -- Carry in of the add/sub (ADD_CIN = '0' --> ADD , ADD_CIN = '1' --> SUB)
    signal S_LOGIC_SEL : std_logic_vector (3 downto 0); -- Selects the correct logical operation
    signal S_COMP_SEL : std_logic_vector (2 downto 0); -- Selection signal for the comparator
    signal S_COMP_TYPE : std_logic; -- Signed( = '1') or unsigned ( = '0' )comparison --> it changes only for lower (<) comparison 
    signal S_SHIFT_CONFIG : std_logic_vector (1 downto 0); -- selects direction and type of the shift
    -- output signals of MUL e ALU
    signal MUL_OUTPUT, ALU_OUTPUT : std_logic_vector(NBIT - 1 downto 0);
    -- OUTPUT OF THE MUX THAT SELECTS DATA FROM ALU OR MULTIPLIER
    signal MUX_UNIT_OUT : std_logic_vector(NBIT - 1 downto 0);
    signal rs1_data_in, rs2_data_in : std_logic_vector(NBIT - 1 downto 0); -- SIgnal going from the mux selecting between RF or FWD unit to the actual RS1/RS2 registres
    signal rd_addr_final : std_logic_vector(NBIT_IDX - 1 downto 0); -- Destination register after accoutning for the possible jump and link instructions
    signal alu_data_to_out : std_logic_vector(NBIT - 1 downto 0); -- Alu output or NPC in (if the link signal is enabled)
    constant link_reg : std_logic_vector(NBIT_IDX - 1 downto 0) := std_logic_vector(to_unsigned(31, NBIT_IDX));

begin
    nrst_final <= NRST and EXECUTE_CTRL.NRST_STAGE;
    en_raluout <= EN_STAGE and EXECUTE_CTRL.EN_RALUOUT;
    -----------------------------------------------------------------
    --                      EXECUTE STAGE                          --
    -----------------------------------------------------------------

    MUX_FWD_RS1 : MUX21
    port map(
        A => EXECUTE_DIN.RS1_DATA,
        B => RS1_FWD_DATA,
        Q => rs1_data_in,
        SEL => RS1_FWD_EN
    );
    MUX_FWD_RS2 : MUX21
    port map(
        A => EXECUTE_DIN.RS2_DATA,
        B => RS2_FWD_DATA,
        Q => rs2_data_in,
        SEL => RS2_FWD_EN
    );

    -- ALU operands & registers
    MUX_A : component MUX21 port map(EXECUTE_DIN.NPC_IN, rs1_data_in, operand_a, EXECUTE_CTRL.MUX_A_SEL);
    MUX_B : component MUX21 port map(rs2_data_in, EXECUTE_DIN.RIMM_DATA, operand_b, EXECUTE_CTRL.MUX_B_SEL);
    ALU_OUT <= ALU_OUTPUT;

    ENCODER_INST : ALU_ENCODER
    port map(
        CMD => EXECUTE_CTRL.ALU_OP,
        MUX_OUT_SEL => S_MUX_OUT_SEL,
        MULT_EN => S_MULT_EN,
        ADD_CIN => S_ADD_CIN,
        LOGIC_SEL => S_LOGIC_SEL,
        COMP_SEL => S_COMP_SEL,
        COMP_TYPE => S_COMP_TYPE,
        SHIFT_CONFIG => S_SHIFT_CONFIG
    );

    ALU_CMP : ALU_DBG
    generic map(
        NBIT => 32
    )
    port map(
        REG_A => operand_a,
        REG_B => operand_b,
        -- control signals coming from the encoder
        C_MUX_OUT_SEL => S_MUX_OUT_SEL,
        C_ADD_CIN => S_ADD_CIN,
        C_LOGIC_SEL => S_LOGIC_SEL,
        C_COMP_SEL => S_COMP_SEL,
        C_COMP_TYPE => S_COMP_TYPE,
        C_SHIFT_CONFIG => S_SHIFT_CONFIG,
        -- Output signal
        ALU_OUT => ALU_OUTPUT
    );

    MULT_INST : BOOTHMUL_pipelined
    generic map(
        NBIT => 32)
    port map(
        CLK => CLK,
        RST => NRST,
        EN => EN_STAGE,
        A => operand_a,
        B => operand_b,
        RES => MUL_OUTPUT,

        START => S_MULT_EN,
        BUSY => MUL_BUSY,
        DONE => MUL_DONE
    );

    -- Select the ALU or the multiplier
    MUX_UNIT : MUX21
    generic map(
        NBIT => 32
    )
    port map(
        A => ALU_OUTPUT,
        B => MUL_OUTPUT,
        Q => MUX_UNIT_OUT,
        SEL => MUX_UNIT_SEL
    );
    
    -- Link mode = send the NPC in to the ALU_OUT register to be written to R31
    LINK_OUT: entity work.MUX21
     generic map(
        NBIT => NBIT
    )
     port map(
        A => MUX_UNIT_OUT,
        B => EXECUTE_DIN.NPC_IN,
        Q => alu_data_to_out,
        SEL => EXECUTE_CTRL.LINK_EN
    );

    -- Register the ALU data
    ALU_OUT_REG : component REG port map(alu_data_to_out, EXECUTE_DOUT.ALU_DATA, CLK, en_raluout, nrst_final);

    -- Conditional branching
    ZERO_CHK : component EQ_ZERO port map(rs1_data_in, zero_flag);

    BRANCH_SEL : component BRANCH_SELECTOR port map(
        BRANCH_MODE => EXECUTE_CTRL.BRANCH_MODE,
        EQ_ZERO_RSLT => zero_flag,
        BRANCH_SEL => branch_select
    );
    -- Branch signal gets registered in the CU
    EXECUTE_DOUT.BRANCH <= branch_select;
    MUX_NPC : component MUX21 port map(EXECUTE_DIN.NPC_IN, ALU_OUTPUT, EXECUTE_DOUT.NPC_OUT, branch_select); -- Select either the "standard" NPC from decode stage (PC + 1) or the ALU out (PC + IMM_SHORT) for conditional branch
    -- NPC_OUT_REG : component REG port map(npc_mux_out, EXECUTE_DOUT.NPC_OUT, CLK, EN_STAGE, nrst_final);

    -- Link mode 
    LINK_MUX: entity work.MUX21
     generic map(
        NBIT => NBIT_IDX
    )
     port map(
        A => EXECUTE_DIN.RD_ADDR_IN,
        B => link_reg,
        Q => rd_addr_final,
        SEL => EXECUTE_CTRL.LINK_EN
    );
    
    -- Propagate ram_data, RD and NPC
    REG_WADDR_PROP_EXE : REG
    generic map(NBIT => NBIT_IDX)
    port map(rd_addr_final, EXECUTE_DOUT.RD_ADDR_OUT, CLK, EN_STAGE, nrst_final);

    REG_RAMDATA_PROP_EXE : REG port map(rs2_data_in, EXECUTE_DOUT.RAM_DATA, CLK, EN_STAGE, nrst_final);
end STRUCTURAL;