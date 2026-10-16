
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.myTypes.all;
use work.constants.all;

entity tb_ALU is
-- Testbench: nessuna porta esterna
end entity tb_ALU;

architecture behavior of tb_ALU is

    -- Costanti di simulazione
    constant NBIT : natural := 32;
    constant CLK_PERIOD : time := 10 ns;

    -- Segnali di I/O della UUT
    signal REG_A    : std_logic_vector(NBIT - 1 downto 0) := (others => '0');
    signal REG_B    : std_logic_vector(NBIT - 1 downto 0) := (others => '0');
    signal CMD      : aluOp := NOP;
    signal CLK      : std_logic := '0';
    signal EN_MUL   : std_logic := '0';
    signal RST      : std_logic := '0';
    signal ALU_OUT  : std_logic_vector(NBIT - 1 downto 0);
    
component ALU is
    generic (
        NBIT : natural := 32
    );
    port (
        REG_A, REG_B : in std_logic_vector(NBIT - 1 downto 0); -- Input operands
        CMD : in aluOp; -- Alu operation selection
        CLK : in std_logic;
        EN_MUL : in std_logic ;
        RST : in std_logic;
        ALU_OUT : out std_logic_vector(NBIT - 1 downto 0) -- Output
    );
end component;


begin

    -- Instanziazione della ALU (Unit Under Test)
    UUT: ALU
        generic map (
            NBIT => NBIT
        )
        port map (
            REG_A   => REG_A,
            REG_B   => REG_B,
            CMD     => CMD,
            CLK     => CLK,
            EN_MUL  => EN_MUL,
            RST     => RST,
            ALU_OUT => ALU_OUT
        );

    -- Generazione del segnale di Clock
    clk_process: process
    begin
        CLK <= '0';
        wait for CLK_PERIOD / 2;
        CLK <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Processo principale di Stimolo
    stim_proc: process
    begin
        -- 1. Inizializzazione e Reset Asincrono
        RST <= '0'; -- Reset attivo basso
        EN_MUL <= '0';
        REG_A <= (others => '0');
        REG_B <= (others => '0');
        CMD   <= NOP;
        wait for CLK_PERIOD * 2;
        
        RST <= '1'; -- Rilascio del Reset
        wait until rising_edge(CLK);

        ------------------------------------------------------------------------
        -- TEST OPERAZIONI ARITMETICHE
        ------------------------------------------------------------------------
        -- ADD: 15 + 10 = 25
        REG_A <= x"0000000F";
        REG_B <= x"0000000A";
        CMD   <= ADD;
        wait for CLK_PERIOD;

        -- SUB: 15 - 10 = 5
        CMD   <= SUB;
        wait for CLK_PERIOD;

        ------------------------------------------------------------------------
        -- TEST OPERAZIONI LOGICHE
        ------------------------------------------------------------------------
        REG_A <= x"FF00FF00";
        REG_B <= x"F0F0F0F0";

        CMD <= AND_OP;  wait for CLK_PERIOD; -- Out expected: x"F000F000"
        CMD <= NAND_OP; wait for CLK_PERIOD; -- Out expected: x"0FFF0FFF"
        CMD <= OR_OP;   wait for CLK_PERIOD; -- Out expected: x"FFF0FF00"
        CMD <= NOR_OP;  wait for CLK_PERIOD; -- Out expected: x"000F00FF"
        CMD <= XOR_OP;  wait for CLK_PERIOD; -- Out expected: x"0F100F10"
        CMD <= XNOR_OP; wait for CLK_PERIOD; -- Out expected: x"F0EF10EF"

        ------------------------------------------------------------------------
        -- TEST SHIFT OPERAZIONI
        ------------------------------------------------------------------------
        REG_A <= x"8000000F"; -- Valore negativo se interpretato in 2's complement
        REG_B <= x"00000004"; -- Shift di 4 posizioni

        CMD <= SLL_OP; wait for CLK_PERIOD; -- Shift Left Logical
        CMD <= SRL_OP; wait for CLK_PERIOD; -- Shift Right Logical
        CMD <= SRA_OP; wait for CLK_PERIOD; -- Shift Right Arithmetic (mantiene il segno)

        ------------------------------------------------------------------------
        -- TEST COMPARATORI
        ------------------------------------------------------------------------
        -- Caso 1: A > B (con valori positivi)
        REG_A <= x"00000020"; -- 32
        REG_B <= x"00000010"; -- 16

        CMD <= EQ;   wait for CLK_PERIOD;
        CMD <= GT;   wait for CLK_PERIOD;
        CMD <= GE;   wait for CLK_PERIOD;
        CMD <= LT;   wait for CLK_PERIOD;
        CMD <= LE;   wait for CLK_PERIOD;

        -- Caso 2: Confronto Signed vs Unsigned con numeri negativi
        REG_A <= x"FFFFFFFF"; -- -1 in signed, 4294967295 in unsigned
        REG_B <= x"00000001"; -- 1

        CMD <= LT;   wait for CLK_PERIOD; -- Signed: -1 < 1  --> VERO (1)
        CMD <= LT_U; wait for CLK_PERIOD; -- Unsigned: MAX > 1 --> FALSO (0)

        ------------------------------------------------------------------------
        -- TEST MOLTIPLICATORE PIPELINED (Latenza di 4 cicli di clock)
        ------------------------------------------------------------------------
        REG_A  <= x"00000006"; -- 6
        REG_B  <= x"00000007"; -- 7
        CMD    <= MULT;
        EN_MUL <= '1'; -- Abilita la pipeline della moltiplicazione

        -- Attesa dei 4 cicli di latenza della pipeline
        wait for CLK_PERIOD * 20; 
        
        -- Disabilita la moltiplicazione e torna in NOP
        EN_MUL <= '0';
        CMD    <= NOP;
        wait for CLK_PERIOD * 2;

        -- Fine simulazione
        report "Simulazione completata con successo!" severity note;
        wait;
    end process;

end architecture behavior;
