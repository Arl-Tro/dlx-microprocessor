library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.myTypes.all;
use work.cpu_32b_types.all;

-- Fetch Stage implementation

entity DECODE_STAGE is
    generic (
        NBIT : natural := 32;
        NBIT_IDX : natural := 5 -- Number of bits used to select a signle register, also determines the number of registers
    );

    port (
        -- Global
        CLK : in std_logic;
        NRST : in std_logic; -- Reset, activelow
        EN_STAGE : in std_logic; -- Stage enable signal

        -- Decode stage, control
        DECODE_CTRL : in id_ctrl_in_t;

        -- Decode stage, data (all are registered inside the current stage)
        DECODE_DIN : in id_data_in_t;
        DECODE_DOUT : out id_data_out_t;

        -- Register file read interface
        RS1_ADDR, RS2_ADDR, RD_ADDR_UNBUFFERED : buffer std_logic_vector (NBIT_IDX - 1 downto 0); -- Needed for hazard detection (but also internally, thus buffer type)
        RS1_RF_DATA, RS2_RF_DATA : in std_logic_vector (NBIT - 1 downto 0) -- Data from the register file

        
    );
end DECODE_STAGE;

architecture STRUCTURAL of DECODE_STAGE is

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
    component BIT_EXT is
        generic (
            NBIT_OUT : natural := 32; -- How many bits is the output supposed to have
            NBIT_IN : natural := 16 -- How many bits does the input have?
        );
        port (
            D : in std_logic_vector (NBIT_IN - 1 downto 0); -- Input data
            ZERO_SIGN_EXT : in std_logic; -- If 0, the input is zero extended, if 1 the input is sign extended
            EXTENDED : out std_logic_vector (NBIT_OUT - 1 downto 0) -- Output data
        );
    end component;

    -- Signals
    signal nrst_final : std_logic; -- NRST signal made by the AND (reset if either the global or control reset signals are active) of the global and control resets
    signal en_rs1, en_rs2, en_rimm : std_logic; -- Enable signals ANDed with EN_STAGE
    -- Decode stage
    -- signal rs1_data_rf, rs2_data_rf : std_logic_vector(NBIT - 1 downto 0); -- Wired from register file output to the input of the RS1 and RS2 registers
    signal imm_short : std_logic_vector(NBIT - 1 downto 0); -- Wired from IR_IN to the right bits for immediate of 16 bits (to be sign extended)
    signal imm_long : std_logic_vector(NBIT - 1 downto 0); -- Wired from IR_IN to the right bits for immediate of 26 bits for jumps
    signal imm_reg_in : std_logic_vector(NBIT - 1 downto 0); -- Wired to the input of the immediate register
    signal rd_addr : std_logic_vector(NBIT_IDX - 1 downto 0); -- Used to propagate the output of the RD mux to the Rd register
    signal rf_data_link : std_logic_vector(NBIT - 1 downto 0); -- Used to propagate the output of the mux chosing rd_data or npc as data
    signal rf_addr_link : std_logic_vector(NBIT_IDX - 1 downto 0); -- Used to propagate the output of the mux chosing rd_addr or 31
    signal link_reg : std_logic_vector(NBIT_IDX - 1 downto 0) := std_logic_vector(to_unsigned(31, NBIT_IDX));
    signal rd_rr, rd_not_rr : std_logic_vector(NBIT_IDX - 1 downto 0); -- Signals for extracting RD from the IR, used to debug, RR for R type ops, not RR for other ops

begin
    nrst_final <= NRST and DECODE_CTRL.NRST_STAGE; -- Only used for pipeline registers, other components used the global NRST
    en_rs1 <= EN_STAGE and DECODE_CTRL.EN_RS1;
    en_rs2 <= EN_STAGE and DECODE_CTRL.EN_RS2;
    en_rimm <= EN_STAGE and DECODE_CTRL.EN_RIMM;

    -----------------------------------------------------------------
    --                      DECODE STAGE                           --
    -----------------------------------------------------------------

    -- Split the IR
    rs1_addr <= DECODE_DIN.IR_IN(25 downto 21); -- Source register B address
    rs2_addr <= DECODE_DIN.IR_IN(20 downto 16); -- Source register A address

    BIT_EXT_short_imm : BIT_EXT
    generic map(
        NBIT_OUT => NBIT,
        NBIT_IN => 16
    )
    port map(
        D => DECODE_DIN.IR_IN(15 downto 0), -- 16 LSBs
        ZERO_SIGN_EXT => DECODE_CTRL.SIGN_IMMEDIATE,
        EXTENDED => imm_short
    );

    BIT_EXT_long_imm : BIT_EXT
    generic map(
        NBIT_OUT => NBIT,
        NBIT_IN => 26
    )
    port map(
        D => DECODE_DIN.IR_IN(25 downto 0), -- 26 LSBs
        ZERO_SIGN_EXT => DECODE_CTRL.SIGN_IMMEDIATE,
        EXTENDED => imm_long
    );

    -- Select the short or long immediate
    IMM_MUX : MUX21 port map(imm_short, imm_long, imm_reg_in, DECODE_CTRL.SHORT_LONG_IMMEDIATE);

    -- The destination address may be in different position for RR or RI type operations, handled thorugh this mux and the is_rr_op signal
    rd_not_rr <= DECODE_DIN.IR_IN(20 downto 16);
    rd_rr <= DECODE_DIN.IR_IN(15 downto 11);

    RD_MUX : MUX21
    generic map(NBIT => NBIT_IDX)
    port map(
        rd_not_rr, rd_rr, rd_addr, DECODE_CTRL.IS_RR_OP
    );

    RD_ADDR_UNBUFFERED <= rd_addr;


    -- FWD MUXes


    -- Output registers
    REG_RS1 : component REG port map(RS1_RF_DATA, DECODE_DOUT.RS1_DATA, CLK, en_rs1, nrst_final);
    REG_RS2 : component REG port map(RS2_RF_DATA, DECODE_DOUT.RS2_DATA, CLK, en_rs2, nrst_final);
    REG_IMM : component REG port map(imm_reg_in, DECODE_DOUT.RIMM_DATA, CLK, en_rimm, nrst_final); -- For 16b immediates

    -- Propagate the destination register and NPC
    REG_NPC_PROP_DEC : component REG port map(DECODE_DIN.NPC_IN, DECODE_DOUT.NPC_OUT, CLK, EN_STAGE, nrst_final);

    REG_WADDR_PROP_DEC : component REG
        generic map(NBIT => NBIT_IDX)
        port map(rd_addr, DECODE_DOUT.RD_ADDR_OUT, CLK, EN_STAGE, nrst_final);

    end;