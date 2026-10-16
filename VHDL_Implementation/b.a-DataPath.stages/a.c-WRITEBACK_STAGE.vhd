library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.myTypes.all;
use work.cpu_32b_types.all;

-- Fetch Stage implementation

entity WRITEBACK_STAGE is
    generic (
        NBIT : natural := 32;
        NBIT_IDX : natural := 5 -- Number of bits used to select a signle register, also determines the number of registers

    );

    port (
        -- Global
        CLK : in std_logic;
        NRST : in std_logic; -- Reset, activelow
        EN_STAGE : in std_logic; -- Stage enable signal

        -- Write Back, control signals
        WRITEBACK_CTRL : in wb_ctrl_in_t;

        -- WriteBack, data signals
        WRITEBACK_DIN : in wb_data_in_t;
        WRITEBACK_DOUT : out wb_data_out_t

    );
end WRITEBACK_STAGE;

architecture STRUCTURAL of WRITEBACK_STAGE is

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

    -- Signals
    signal nrst_final : std_logic; -- NRST signal made by the AND (reset if either the global or control reset signals are active) of the global and control resets

    -- Writeback stage
    signal wb_data : std_logic_vector(NBIT - 1 downto 0); -- Data to be written, unregistered

begin
    nrst_final <= NRST and WRITEBACK_CTRL.NRST_STAGE;
    -----------------------------------------------------------------
    --                     WRITEBACK STAGE                         --
    -----------------------------------------------------------------

    -- Select data to write
    WB_MUX : component MUX21 port map(WRITEBACK_DIN.ALU_DATA_IN, WRITEBACK_DIN.RAM_DATA_IN, wb_data, WRITEBACK_CTRL.WB_SEL);
    WRITEBACK_DOUT.DATA_FORM_MEM <= wb_data;
    
    -- Propagate Rd_data
    REG_WDATA_PROP_WB : component REG port map(wb_data, WRITEBACK_DOUT.RD_DATA_OUT, CLK, EN_STAGE, nrst_final);
    -- Propagate Rd_addr
    REG_WADDR_PROP_WB : component REG
        generic map(NBIT => NBIT_IDX)
        port map(WRITEBACK_DIN.RD_ADDR_IN, WRITEBACK_DOUT.RD_ADDR_OUT, CLK, EN_STAGE, nrst_final);
    end;