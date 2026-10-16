library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use WORK.constants.all;

entity tb_data_memory_system is
end tb_data_memory_system;

architecture testbench of tb_data_memory_system is

    constant NBIT      : integer := 32;
    constant NBIT_ADDR : integer := 5;
    constant M         : integer := 8;  -- globals
    constant N         : integer := 8;  -- 8 IN, 8 LOCAL, 8 OUT
    constant F         : integer := 3;  -- n° windows
    constant RAM_DEPTH : integer := 1024;

    constant CLK_PERIOD : time := 10 ns;

    signal CLK               : std_logic := '0';
    signal RESET             : std_logic := '0';
    signal ENABLE            : std_logic := '1';

    -- pipeline register file interface
    signal RF_RD1_EN         : std_logic := '0';
    signal RF_RD2_EN         : std_logic := '0';
    signal RF_WR_EN          : std_logic := '0';
    signal RF_ADD_WR         : std_logic_vector(NBIT_ADDR - 1 downto 0) := (others => '0');
    signal RF_ADD_RD1        : std_logic_vector(NBIT_ADDR - 1 downto 0) := (others => '0');
    signal RF_ADD_RD2        : std_logic_vector(NBIT_ADDR - 1 downto 0) := (others => '0');
    signal RF_DATA_IN        : std_logic_vector(NBIT - 1 downto 0) := (others => '0');
    signal RF_OUT1           : std_logic_vector(NBIT - 1 downto 0);
    signal RF_OUT2           : std_logic_vector(NBIT - 1 downto 0);
    
    signal CALL              : std_logic := '0';
    signal RETURN_S          : std_logic := '0';

    -- pipeline data memory interface
    signal CPU_MEM_ADDR      : std_logic_vector(NBIT - 1 downto 0) := (others => '0');
    signal CPU_DATA_TO_MEM   : std_logic_vector(NBIT - 1 downto 0) := (others => '0');
    signal CPU_DATA_FROM_MEM : std_logic_vector(NBIT - 1 downto 0);
    signal CPU_READ_ENABLE   : std_logic := '0';
    signal CPU_WRITE_ENABLE  : std_logic := '0';

    -- Stall signals
    signal SPILL             : std_logic;
    signal FILL              : std_logic;

    -- UUT Component Declaration
    component data_memory_system is
        generic (
            NBIT      : integer := NumBit;
            NBIT_ADDR : integer := NumBit_add;
            M         : integer := GloReg;
            N         : integer := NumRegBlock;
            F         : integer := NumWin;
            RAM_DEPTH : integer := 1024
        );
        port (
            CLK               : in  std_logic;
            RESET             : in  std_logic;
            ENABLE            : in  std_logic;
            RF_RD1_EN         : in  std_logic;
            RF_RD2_EN         : in  std_logic;
            RF_WR_EN          : in  std_logic;
            RF_ADD_WR         : in  std_logic_vector(NBIT_ADDR - 1 downto 0);
            RF_ADD_RD1        : in  std_logic_vector(NBIT_ADDR - 1 downto 0);
            RF_ADD_RD2        : in  std_logic_vector(NBIT_ADDR - 1 downto 0);
            RF_DATA_IN        : in  std_logic_vector(NBIT - 1 downto 0);
            RF_OUT1           : out std_logic_vector(NBIT - 1 downto 0);
            RF_OUT2           : out std_logic_vector(NBIT - 1 downto 0);
            CALL              : in  std_logic;
            RETURN_S          : in  std_logic;
            CPU_MEM_ADDR      : in  std_logic_vector(NBIT - 1 downto 0);
            CPU_DATA_TO_MEM   : in  std_logic_vector(NBIT - 1 downto 0);
            CPU_DATA_FROM_MEM : out std_logic_vector(NBIT - 1 downto 0);
            CPU_READ_ENABLE   : in  std_logic;
            CPU_WRITE_ENABLE  : in  std_logic;
            SPILL             : out std_logic;
            FILL              : out std_logic
        );
    end component;

begin

    -- Clock generation process
    CLK_GEN : process
    begin
        CLK <= '0';
        wait for CLK_PERIOD / 2;
        CLK <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Unit Under Test (UUT) instantiation
    UUT : data_memory_system
        generic map (
            NBIT      => NBIT,
            NBIT_ADDR => NBIT_ADDR,
            M         => M,
            N         => N,
            F         => F,
            RAM_DEPTH => RAM_DEPTH
        )
        port map (
            CLK               => CLK,
            RESET             => RESET,
            ENABLE            => ENABLE,
            RF_RD1_EN         => RF_RD1_EN,
            RF_RD2_EN         => RF_RD2_EN,
            RF_WR_EN          => RF_WR_EN,
            RF_ADD_WR         => RF_ADD_WR,
            RF_ADD_RD1        => RF_ADD_RD1,
            RF_ADD_RD2        => RF_ADD_RD2,
            RF_DATA_IN        => RF_DATA_IN,
            RF_OUT1           => RF_OUT1,
            RF_OUT2           => RF_OUT2,
            CALL              => CALL,
            RETURN_S          => RETURN_S,
            CPU_MEM_ADDR      => CPU_MEM_ADDR,
            CPU_DATA_TO_MEM   => CPU_DATA_TO_MEM,
            CPU_DATA_FROM_MEM => CPU_DATA_FROM_MEM,
            CPU_READ_ENABLE   => CPU_READ_ENABLE,
            CPU_WRITE_ENABLE  => CPU_WRITE_ENABLE,
            SPILL             => SPILL,
            FILL              => FILL
        );

    -- Stimulus Process
    STIMULUS : process
    begin

        -- Step 1: System Reset
        RESET <= '1';
        wait for CLK_PERIOD * 2;
        RESET <= '0';
        wait for CLK_PERIOD;

        -- Step 2: register file standard access (Window 0)
        -- write 0xAAAABBBB into Local register 10 (vaddr = 10 -> r10)
        RF_WR_EN  <= '1';
        RF_ADD_WR <= std_logic_vector(to_unsigned(10, NBIT_ADDR));
        RF_DATA_IN <= x"AAAABBBB";
        wait for CLK_PERIOD;
        RF_WR_EN  <= '0';

        -- read back from register 10 on RD1 port
        RF_RD1_EN  <= '1';
        RF_ADD_RD1 <= std_logic_vector(to_unsigned(10, NBIT_ADDR));
        wait for CLK_PERIOD;
        RF_RD1_EN  <= '0';


        -- Step 3: pipeline Data RAM Access (SW and LW in Normal Mode)
        -- write 0x1234_5678 to RAM Address 0x00000020
        CPU_WRITE_ENABLE <= '1';
        CPU_MEM_ADDR     <= x"00000020";
        CPU_DATA_TO_MEM  <= x"12345678";
        wait for CLK_PERIOD;
        CPU_WRITE_ENABLE <= '0';

        -- read back from RAM address 0x00000020
        CPU_READ_ENABLE <= '1';
        CPU_MEM_ADDR    <= x"00000020";
        wait for CLK_PERIOD;
        CPU_READ_ENABLE <= '0';

        -- Step 4: forcing register window OVERFLOW (SPILL)
        -- F = 3 windows available. CANSAVE initially = 2.
        
        -- CALL 1 (move to window 1)
        CALL <= '1';
        wait for CLK_PERIOD;
        CALL <= '0';
        wait for CLK_PERIOD;

        -- write dome data to window 1
        RF_WR_EN   <= '1';
        RF_ADD_WR  <= std_logic_vector(to_unsigned(8, NBIT_ADDR)); -- IN reg
        RF_DATA_IN <= x"11112222";
        wait for CLK_PERIOD;
        RF_WR_EN   <= '0';

        -- CALL 2 (move to window 2)
        CALL <= '1';
        wait for CLK_PERIOD;
        CALL <= '0';
        wait for CLK_PERIOD;

        -- CALL 3 (No free windows left -> CANSAVE = 0 -> trigger SPILL)
        CALL <= '1';
        wait for CLK_PERIOD;
        CALL <= '0';

        -- wait during SPILL state until SPILL signal deasserts
        wait until SPILL = '0';
        wait for CLK_PERIOD;

        -- Step 5: forcing register window UNDERFLOW (FILL)
        -- execute consecutive RETURN_S calls
        
        -- RETURN 1
        RETURN_S <= '1';
        wait for CLK_PERIOD;
        RETURN_S <= '0';
        wait for CLK_PERIOD;

        -- RETURN 2
        RETURN_S <= '1';
        wait for CLK_PERIOD;
        RETURN_S <= '0';
        wait for CLK_PERIOD;

        -- RETURN 3 (CANRESTORE = 0 -> trigger FILL from Memory)
        RETURN_S <= '1';
        wait for CLK_PERIOD;
        RETURN_S <= '0';

        -- wait during FILL state until FILL signal deasserts
        wait until FILL = '0';
        wait for CLK_PERIOD * 2;

        -- End Simulation
        assert false report "******************** Simulation Completed ********************" severity note;
        wait;
    end process;

end testbench;