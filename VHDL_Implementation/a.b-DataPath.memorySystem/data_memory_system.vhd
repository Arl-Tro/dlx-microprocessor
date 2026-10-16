library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.myTypes.all;
use work.cpu_32b_types.all;

entity data_memory_system is
    generic (
        NBIT : integer := NBIT; -- Data bus width (32 bits)
        NBIT_ADDR : integer := NBIT_IDX; -- RF Register address width (5 bits = 32 regs)
        M : integer := G_REGS; -- Global registers count
        N : integer := BLOCK_REGS; -- Registers per IN/LOCAL/OUT block
        F : integer := TOT_WINDOWS; -- Total register windows count
        RAM_DEPTH : integer := DRAM_D -- Data RAM depth 
    );
    port (
        CLK : in std_logic;
        RESET : in std_logic;
        ENABLE : in std_logic;

        -- register file access (ID Stage)
        RF_RD1_EN : in std_logic;
        RF_RD2_EN : in std_logic;
        RF_WR_EN : in std_logic;
        RF_ADD_WR : in std_logic_vector(NBIT_ADDR - 1 downto 0);
        RF_ADD_RD1 : in std_logic_vector(NBIT_ADDR - 1 downto 0);
        RF_ADD_RD2 : in std_logic_vector(NBIT_ADDR - 1 downto 0);
        RF_DATA_IN : in std_logic_vector(NBIT - 1 downto 0);
        RF_OUT1 : out std_logic_vector(NBIT - 1 downto 0);
        RF_OUT2 : out std_logic_vector(NBIT - 1 downto 0);

        -- control signals from CU (Id)
        CALL : in std_logic;
        RETURN_S : in std_logic;

        -- data memory access (ex/mem/wb) --> Connect here the rest of the CPU
        CPU_MEM_ADDR : in std_logic_vector(NBIT - 1 downto 0);
        CPU_DATA_TO_MEM : in std_logic_vector(NBIT - 1 downto 0);
        CPU_DATA_FROM_MEM : out std_logic_vector(NBIT - 1 downto 0);
        CPU_READ_ENABLE : in std_logic;
        CPU_WRITE_ENABLE : in std_logic_vector(3 downto 0); -- write from arbiter, bit 0 enables the write to bits 0-7 of the current RAM word, bit 1 8-15 ecc.

        -- pipeline stall signals  (to CU / Hazard Unit)
        SPILL : out std_logic;
        FILL : out std_logic
    );
end data_memory_system;

architecture structural of data_memory_system is

    component register_file_windowed is
        generic (
            NBIT : integer := NBIT;
            NBIT_ADDR : integer := NBIT_ADDR;
            M : integer := M; -- Global registers count
            N : integer := N; -- Registers per IN/LOCAL/OUT block
            F : integer := F -- Total register windows count
        );
        port (
            CLK : in std_logic;
            RESET : in std_logic;
            ENABLE : in std_logic;
            RD1 : in std_logic;
            RD2 : in std_logic;
            WR : in std_logic;
            ADD_WR : in std_logic_vector(NBIT_ADDR - 1 downto 0);
            ADD_RD1 : in std_logic_vector(NBIT_ADDR - 1 downto 0);
            ADD_RD2 : in std_logic_vector(NBIT_ADDR - 1 downto 0);
            DATAIN : in std_logic_vector(NBIT - 1 downto 0);
            OUT1 : out std_logic_vector(NBIT - 1 downto 0);
            OUT2 : out std_logic_vector(NBIT - 1 downto 0);
            CALL : in std_logic;
            RETURN_S : in std_logic;
            SPILL : out std_logic;
            FILL : out std_logic;
            MEM_ADDR : out std_logic_vector(NBIT - 1 downto 0);
            DATA_TO_MEM : out std_logic_vector(NBIT - 1 downto 0);
            DATA_FROM_MEM : in std_logic_vector(NBIT - 1 downto 0);
            MEM_ACK : in std_logic
        );
    end component;
    component data_mem_arbiter is
        generic (
            ADDR_BUS_SIZE : integer := NBIT;
            DATA_BUS_SIZE : integer := NBIT
        );
        port (
            SPILL : in std_logic;
            FILL : in std_logic;
            WRF_MEM_ADDR : in std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
            WRF_DATA_TO_MEM : in std_logic_vector(DATA_BUS_SIZE - 1 downto 0);
            WRF_DATA_FROM_MEM : out std_logic_vector(DATA_BUS_SIZE - 1 downto 0);
            CPU_MEM_ADDR : in std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
            CPU_DATA_TO_MEM : in std_logic_vector(DATA_BUS_SIZE - 1 downto 0);
            CPU_DATA_FROM_MEM : out std_logic_vector(DATA_BUS_SIZE - 1 downto 0);
            CPU_READ_ENABLE : in std_logic;
            CPU_WRITE_ENABLE : in std_logic_vector(3 downto 0);
            RAM_ADDR : out std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
            RAM_DATA_TO_MEM : out std_logic_vector(DATA_BUS_SIZE - 1 downto 0);
            RAM_DATA_FROM_MEM : in std_logic_vector(DATA_BUS_SIZE - 1 downto 0);
            RAM_READ_ENABLE : out std_logic;
            RAM_WRITE_ENABLE : out std_logic_vector(3 downto 0)
        );
    end component;
    component data_ram is
        generic (
            ADDR_BUS_SIZE : integer := NBIT;
            DATA_BUS_SIZE : integer := NBIT;
            RAM_DEPTH : integer := RAM_DEPTH;
            SERIAL_ADDR : integer := RAM_PRINT -- A write here will print on screen in vsim, remove for synthesis
        );
        port (
            CLK : in std_logic;
            RESET : in std_logic;
            ENABLE : in std_logic;
            READ_ENABLE : in std_logic;
            WRITE_ENABLE : in std_logic_vector(3 downto 0);
            ADDR : in std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
            DATA_IN : in std_logic_vector(DATA_BUS_SIZE - 1 downto 0);
            DATA_OUT : out std_logic_vector(DATA_BUS_SIZE - 1 downto 0)
        );
    end component;
    -- internal signals
    signal spill_int : std_logic;
    signal fill_int : std_logic;

    -- conections between WRF and arbiter
    signal wrf_mem_addr_int : std_logic_vector(NBIT - 1 downto 0);
    signal wrf_data_to_mem_int : std_logic_vector(NBIT - 1 downto 0);
    signal wrf_data_from_mem_int : std_logic_vector(NBIT - 1 downto 0);

    -- connections between arbiter and Data RAM
    signal ram_addr_int : std_logic_vector(NBIT - 1 downto 0);
    signal ram_data_to_mem_int : std_logic_vector(NBIT - 1 downto 0);
    signal ram_data_from_mem_int : std_logic_vector(NBIT - 1 downto 0);
    signal ram_read_en_int : std_logic;
    signal ram_write_en_int : std_logic_vector(3 downto 0);

    -- memory ACK signal 
    signal mem_ack_int : std_logic := '1'; -- ricordarsi di collegarlo
begin

    -- propagate stall signals to external interface
    SPILL <= spill_int;
    FILL <= fill_int;

    -- Windowed Register File Instance
    U_WRF : register_file_windowed
    generic map(
        NBIT => NBIT,
        NBIT_ADDR => NBIT_ADDR,
        M => M,
        N => N,
        F => F
    )
    port map(
        CLK => CLK,
        RESET => RESET,
        ENABLE => ENABLE,
        RD1 => RF_RD1_EN,
        RD2 => RF_RD2_EN,
        WR => RF_WR_EN,
        ADD_WR => RF_ADD_WR,
        ADD_RD1 => RF_ADD_RD1,
        ADD_RD2 => RF_ADD_RD2,
        DATAIN => RF_DATA_IN,
        OUT1 => RF_OUT1,
        OUT2 => RF_OUT2,
        CALL => CALL,
        RETURN_S => RETURN_S,
        SPILL => spill_int,
        FILL => fill_int,
        MEM_ADDR => wrf_mem_addr_int,
        DATA_TO_MEM => wrf_data_to_mem_int,
        DATA_FROM_MEM => wrf_data_from_mem_int,
        MEM_ACK => mem_ack_int
    );
    -- data memory arbiter instance
    U_ARBITER : data_mem_arbiter
    generic map(
        ADDR_BUS_SIZE => NBIT,
        DATA_BUS_SIZE => NBIT
    )
    port map(
        SPILL => spill_int,
        FILL => fill_int,
        WRF_MEM_ADDR => wrf_mem_addr_int,
        WRF_DATA_TO_MEM => wrf_data_to_mem_int,
        WRF_DATA_FROM_MEM => wrf_data_from_mem_int,
        CPU_MEM_ADDR => CPU_MEM_ADDR,
        CPU_DATA_TO_MEM => CPU_DATA_TO_MEM,
        CPU_DATA_FROM_MEM => CPU_DATA_FROM_MEM,
        CPU_READ_ENABLE => CPU_READ_ENABLE,
        CPU_WRITE_ENABLE => CPU_WRITE_ENABLE,
        RAM_ADDR => ram_addr_int,
        RAM_DATA_TO_MEM => ram_data_to_mem_int,
        RAM_DATA_FROM_MEM => ram_data_from_mem_int,
        RAM_READ_ENABLE => ram_read_en_int,
        RAM_WRITE_ENABLE => ram_write_en_int
    );
    --  data RAM instance
    U_DRAM : data_ram
    generic map(
        ADDR_BUS_SIZE => NBIT,
        DATA_BUS_SIZE => NBIT,
        RAM_DEPTH => RAM_DEPTH,
        SERIAL_ADDR => RAM_PRINT
    )
    port map(
        CLK => CLK,
        RESET => RESET,
        ENABLE => ENABLE,
        READ_ENABLE => ram_read_en_int,
        WRITE_ENABLE => ram_write_en_int,
        ADDR => ram_addr_int,
        DATA_IN => ram_data_to_mem_int,
        DATA_OUT => ram_data_from_mem_int
    );

end structural;