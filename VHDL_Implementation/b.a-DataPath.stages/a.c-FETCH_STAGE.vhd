library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.myTypes.all;
use work.cpu_32b_types.all;

-- Fetch Stage implementation

-- The NPC in this stage is always updated to PC + 1, if case of branches the external NPC_IN is written to PC

entity FETCH_STAGE is
    generic (
        NBIT : natural := 32;
        NBIT_IDX : natural := 5 -- Number of bits used to select a signle register, also determines the number of registers

    );

    port (
        -- Global
        CLK : in std_logic;
        NRST : in std_logic; -- Reset, activelow
        EN_STAGE : in std_logic; -- Stage enable signal
        STALL : in std_logic; --ToDo: remove
        
        -- Fetch stage, control
        FETCH_CTRL : in if_ctrl_in_t;

        -- Fetch stage, data (all are registered inside the current stage)
        FETCH_DIN : in if_data_in_t;
        FETCH_DOUT : out if_data_out_t

    );
end FETCH_STAGE;

architecture STRUCTURAL of FETCH_STAGE is

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

    component IRAM is
        generic (
            RAM_DEPTH : integer := IRAM_DEPTH;
            I_SIZE : integer := NBIT
        );
        port (
            Rst : in std_logic;
            Addr : in std_logic_vector(I_SIZE - 1 downto 0);
            Dout : out std_logic_vector(I_SIZE - 1 downto 0)
        );

    end component;

    -- Signals
    signal nrst_final : std_logic; -- NRST signal made by the AND (reset if either the global or control reset signals are active) of the global and control resets
    signal en_pc, en_npc, en_ir : std_logic; -- Enable signals ANDed with EN_STAGE

    -- Fetch stage
    signal pc_to_iram : std_logic_vector(NBIT - 1 downto 0); -- Connect output of PC to IRAM ADDR
    signal iram_to_ir : std_logic_vector(NBIT - 1 downto 0); -- Data from IRAM goes to the IR
    signal npc_sequential_in : std_logic_vector(NBIT - 1 downto 0); -- Computed NPC as PC + 1
    signal npc_sequential_out : std_logic_vector(NBIT - 1 downto 0); -- Computed NPC as PC + 1, registered
    signal pc_selected_in : std_logic_vector(NBIT - 1 downto 0);
begin

    nrst_final <= NRST and FETCH_CTRL.NRST_STAGE; -- Only used for pipeline registers, other components used the global NRST
    en_pc <= EN_STAGE and FETCH_CTRL.EN_PC;
    en_npc <= EN_STAGE and FETCH_CTRL.EN_NPC;
    en_ir <= EN_STAGE and FETCH_CTRL.EN_IR;

    -----------------------------------------------------------------
    --                       FETCH STAGE                           --
    -----------------------------------------------------------------
    -- The current implementation should suffice most needs already, the one thing to check is the + 1 in the PC.
    -- Due to how the IRAM entity was given, the memory is 32 bit addressable, not byte adddressable, thus a +1 shifts by 4 Bytes

    PC_MUX : component MUX21 port map(npc_sequential_in, FETCH_DIN.NPC_IN, pc_selected_in, FETCH_CTRL.JUMP_SEL);

    PC : component REG port map(pc_selected_in, pc_to_iram, CLK, en_pc, NRST);

    npc_sequential_in <= std_logic_vector(unsigned(pc_to_iram) + 4); 

    NPC : component REG port map(npc_sequential_in, FETCH_DOUT.NPC_OUT, CLK, en_npc, NRST);

    IRAM_CMP : component IRAM port map(NRST, pc_to_iram, iram_to_ir);

    IR : component REG port map(iram_to_ir, FETCH_DOUT.IR_OUT, CLK, en_ir, nrst_final);

end STRUCTURAL;