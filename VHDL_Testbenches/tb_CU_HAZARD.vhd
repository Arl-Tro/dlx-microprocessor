library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity tb_CU_HAZARD is
end tb_CU_HAZARD;

architecture testbench of tb_CU_HAZARD is

    constant NBIT     : natural := 32;
    constant NBIT_IDX : natural := 5;
    constant CLK_PERIOD : time := 10 ns;


    signal CLK  : std_logic := '0';
    signal NRST : std_logic := '1';

    signal IS_RR_OP : std_logic := '0';

    signal RD_ADDR_FET, RD_ADDR_DEC, RD_ADDR_EX, RD_ADDR_MEM, RD_ADDR_WB : std_logic_vector(NBIT_IDX-1 downto 0) := (others => '0');
    signal RS1_ADDR_IF, RS2_ADDR_IF : std_logic_vector(NBIT_IDX-1 downto 0) := (others => '0');

    signal RD_WEN_EX, RD_WEN_MEM, RD_WEN_WB : std_logic := '0';
    signal IS_LOAD_EX : std_logic := '0';

    signal SPILL, FILL : std_logic := '0';
    signal MEM_RD_REQUEST, MEM_WR_REQUEST : std_logic := '0';
    signal MISPREDICT_FLUSH : std_logic := '0';

    signal EX_MEM_RESULT, MEM_WB_RESULT : std_logic_vector(NBIT-1 downto 0) := (others => '0');
    signal ALU_IN1_RAW, ALU_IN2_RAW : std_logic_vector(NBIT-1 downto 0) := (others => '0');
    signal ALU_IN1, ALU_IN2 : std_logic_vector(NBIT-1 downto 0);

    signal EN_IF, EN_ID, EN_EXE, EN_MEM, EN_WB : std_logic;
    signal STALL, FLUSH_IF_ID, FLUSH_ID_EX : std_logic;

    component CU_HAZARD is
        generic (
            NBIT     : natural := 32;
            NBIT_IDX : natural := 5
        );
        port (
            CLK  : in std_logic;
            NRST : in std_logic;

            IS_RR_OP : in std_logic;

            RD_ADDR_FET : in std_logic_vector(NBIT_IDX-1 downto 0);
            RD_ADDR_DEC : in std_logic_vector(NBIT_IDX-1 downto 0);
            RD_ADDR_EX  : in std_logic_vector(NBIT_IDX-1 downto 0);
            RD_ADDR_MEM : in std_logic_vector(NBIT_IDX-1 downto 0);
            RD_ADDR_WB  : in std_logic_vector(NBIT_IDX-1 downto 0);
            RS1_ADDR_IF, RS2_ADDR_IF : in std_logic_vector(NBIT_IDX-1 downto 0);

            RD_WEN_EX  : in std_logic;
            RD_WEN_MEM : in std_logic;
            RD_WEN_WB  : in std_logic;

            IS_LOAD_EX : in std_logic;

            SPILL : in std_logic;
            FILL  : in std_logic;

            MEM_RD_REQUEST : in std_logic;
            MEM_WR_REQUEST : in std_logic;

            MISPREDICT_FLUSH : in std_logic;

            EX_MEM_RESULT : in std_logic_vector(NBIT-1 downto 0);
            MEM_WB_RESULT : in std_logic_vector(NBIT-1 downto 0);

            ALU_IN1_RAW : in std_logic_vector(NBIT-1 downto 0);
            ALU_IN2_RAW : in std_logic_vector(NBIT-1 downto 0);

            ALU_IN1 : out std_logic_vector(NBIT-1 downto 0);
            ALU_IN2 : out std_logic_vector(NBIT-1 downto 0);

            EN_IF, EN_ID, EN_EXE, EN_MEM, EN_WB : out std_logic;
            STALL       : out std_logic;
            FLUSH_IF_ID : out std_logic;
            FLUSH_ID_EX : out std_logic
        );
    end component;

begin

    CLK_GEN : process
    begin
        CLK <= '0';
        wait for CLK_PERIOD / 2;
        CLK <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    UUT : CU_HAZARD
        generic map (
            NBIT     => NBIT,
            NBIT_IDX => NBIT_IDX
        )
        port map (
            CLK  => CLK,
            NRST => NRST,

            IS_RR_OP => IS_RR_OP,

            RD_ADDR_FET => RD_ADDR_FET,
            RD_ADDR_DEC => RD_ADDR_DEC,
            RD_ADDR_EX  => RD_ADDR_EX,
            RD_ADDR_MEM => RD_ADDR_MEM,
            RD_ADDR_WB  => RD_ADDR_WB,
            RS1_ADDR_IF => RS1_ADDR_IF,
            RS2_ADDR_IF => RS2_ADDR_IF,

            RD_WEN_EX  => RD_WEN_EX,
            RD_WEN_MEM => RD_WEN_MEM,
            RD_WEN_WB  => RD_WEN_WB,

            IS_LOAD_EX => IS_LOAD_EX,

            SPILL => SPILL,
            FILL  => FILL,

            MEM_RD_REQUEST => MEM_RD_REQUEST,
            MEM_WR_REQUEST => MEM_WR_REQUEST,

            MISPREDICT_FLUSH => MISPREDICT_FLUSH,

            EX_MEM_RESULT => EX_MEM_RESULT,
            MEM_WB_RESULT => MEM_WB_RESULT,

            ALU_IN1_RAW => ALU_IN1_RAW,
            ALU_IN2_RAW => ALU_IN2_RAW,

            ALU_IN1 => ALU_IN1,
            ALU_IN2 => ALU_IN2,

            EN_IF  => EN_IF,
            EN_ID  => EN_ID,
            EN_EXE => EN_EXE,
            EN_MEM => EN_MEM,
            EN_WB  => EN_WB,

            STALL       => STALL,
            FLUSH_IF_ID => FLUSH_IF_ID,
            FLUSH_ID_EX => FLUSH_ID_EX
        );

    STIMULUS : process
    begin
        IS_RR_OP <= '1';

        -- Reset
        NRST <= '0';
        wait for CLK_PERIOD * 2;
        NRST <= '1';
        wait for CLK_PERIOD;

        -----------------------------------------------------------------
        -- Test 1: Load-use hazard
        -----------------------------------------------------------------
        RS1_ADDR_IF <= conv_std_logic_vector(3, NBIT_IDX);
        RS2_ADDR_IF <= conv_std_logic_vector(0, NBIT_IDX);
        RD_ADDR_EX  <= conv_std_logic_vector(3, NBIT_IDX);
        RD_WEN_EX   <= '1';
        IS_LOAD_EX  <= '1';
        wait for CLK_PERIOD;

        assert STALL = '1'
            report "TEST 1 FAILED: load-use hazard did not assert STALL" severity error;
        assert EN_IF = '0' and EN_ID = '0'
            report "TEST 1 FAILED: load-use hazard did not freeze IF/ID" severity error;
        report "TEST 1 PASSED: load-use hazard detected" severity note;

        IS_LOAD_EX <= '0';
        RD_WEN_EX  <= '0';
        wait for CLK_PERIOD;

        -----------------------------------------------------------------
        -- Test 2: Forwarding from EX/MEM (mem_hazard)
        -----------------------------------------------------------------
        RS1_ADDR_IF <= conv_std_logic_vector(5, NBIT_IDX);
        RS2_ADDR_IF <= conv_std_logic_vector(0, NBIT_IDX);
        wait for CLK_PERIOD;

        RD_ADDR_MEM   <= conv_std_logic_vector(5, NBIT_IDX);
        RD_WEN_MEM    <= '1';
        EX_MEM_RESULT <= x"000000AA";
        ALU_IN1_RAW   <= x"DEADBEEF";
        wait for 1 ps;

        assert ALU_IN1 = x"000000AA"
            report "TEST 2 FAILED: ALU_IN1 not forwarded from EX/MEM" severity error;
        report "TEST 2 PASSED: forwarding from EX/MEM (mem_hazard) works" severity note;

        wait for CLK_PERIOD;
        RD_WEN_MEM <= '0';

        -----------------------------------------------------------------
        -- Test 3: Forwarding from MEM/WB (wb_hazard)
        -----------------------------------------------------------------
        RS1_ADDR_IF <= conv_std_logic_vector(7, NBIT_IDX);
        RS2_ADDR_IF <= conv_std_logic_vector(0, NBIT_IDX);
        wait for CLK_PERIOD;

        RD_ADDR_WB    <= conv_std_logic_vector(7, NBIT_IDX);
        RD_WEN_WB     <= '1';
        MEM_WB_RESULT <= x"000000BB";
        ALU_IN1_RAW   <= x"DEADBEEF";
        wait for 1 ps;

        assert ALU_IN1 = x"000000BB"
            report "TEST 3 FAILED: ALU_IN1 not forwarded from MEM/WB" severity error;
        report "TEST 3 PASSED: forwarding from MEM/WB (wb_hazard) works" severity note;

        wait for CLK_PERIOD;
        RD_WEN_WB <= '0';

        -----------------------------------------------------------------
        -- Test 4: EX/MEM has priority over MEM/WB when both match
        -----------------------------------------------------------------
        RS1_ADDR_IF <= conv_std_logic_vector(9, NBIT_IDX);
        RS2_ADDR_IF <= conv_std_logic_vector(0, NBIT_IDX);
        wait for CLK_PERIOD;

        RD_ADDR_MEM   <= conv_std_logic_vector(9, NBIT_IDX);
        RD_WEN_MEM    <= '1';
        EX_MEM_RESULT <= x"000000CC";

        RD_ADDR_WB    <= conv_std_logic_vector(9, NBIT_IDX);
        RD_WEN_WB     <= '1';
        MEM_WB_RESULT <= x"000000DD";
        wait for 1 ps;

        assert ALU_IN1 = x"000000CC"
            report "TEST 4 FAILED: EX/MEM forwarding did not take priority over MEM/WB" severity error;
        report "TEST 4 PASSED: EX/MEM priority over MEM/WB confirmed" severity note;

        wait for CLK_PERIOD;
        RD_WEN_MEM <= '0';
        RD_WEN_WB  <= '0';

        -----------------------------------------------------------------
        -- Test 5: SPILL freeze
        -----------------------------------------------------------------
        SPILL <= '1';
        wait for CLK_PERIOD;

        assert STALL = '1'
            report "TEST 5 FAILED: SPILL did not assert STALL" severity error;
        assert EN_IF = '0' and EN_ID = '0' and EN_EXE = '0' and EN_MEM = '0'
            report "TEST 5 FAILED: SPILL did not freeze IF/ID/EXE/MEM" severity error;
        report "TEST 5 PASSED: SPILL freeze detected" severity note;

        -----------------------------------------------------------------
        -- Test 6: structural hazard, CPU load/store in MEM during SPILL
        -----------------------------------------------------------------
        MEM_RD_REQUEST <= '1';
        wait for CLK_PERIOD;

        assert STALL = '1'
            report "TEST 6 FAILED: structural hazard vs SPILL not detected" severity error;
        report "TEST 6 PASSED: structural hazard vs SPILL detected" severity note;

        SPILL <= '0';
        MEM_RD_REQUEST <= '0';
        wait for CLK_PERIOD;

        assert STALL = '0'
            report "TEST 6b FAILED: STALL did not clear after SPILL/structural hazard ended" severity error;
        report "TEST 6b PASSED: STALL cleared correctly" severity note;

        -----------------------------------------------------------------
        -- Test 7: misprediction flush
        -----------------------------------------------------------------
        MISPREDICT_FLUSH <= '1';
        wait for CLK_PERIOD;

        assert FLUSH_IF_ID = '1' and FLUSH_ID_EX = '1'
            report "TEST 7 FAILED: misprediction did not flush IF/ID and ID/EX" severity error;
        report "TEST 7 PASSED: misprediction flush detected" severity note;

        MISPREDICT_FLUSH <= '0';
        wait for CLK_PERIOD;

        assert false report "******************** Simulation Completed ********************" severity note;
        wait;
    end process;

end testbench;
