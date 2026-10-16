
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.myTypes.all;
use work.constants.all;

entity tb_ALU is
    -- Testbench: nessuna porta esterna
    constant RADIX : integer := 2;
end entity tb_ALU;

architecture behavior of tb_ALU is

    -- Costanti di simulazione
    constant NBIT : natural := 32;
    constant CLK_PERIOD : time := 10 ns;

    -- Funzione per stampare i valori (AI, non critica)
    function slv_to_hex(value : std_logic_vector) return string is
        constant HEX_DIGITS : string := "0123456789ABCDEF";
        constant HEX_LENGTH : natural := (value'length + 3) / 4;
        variable padded_value : std_logic_vector(HEX_LENGTH * 4 - 1 downto 0);
        variable nibble : std_logic_vector(3 downto 0);
        variable result : string(1 to HEX_LENGTH);
    begin
        padded_value := (others => '0');
        padded_value(value'length - 1 downto 0) := value;

        for index in result'range loop
            nibble := padded_value(padded_value'high - (index - 1) * 4 downto
                padded_value'high - (index - 1) * 4 - 3);
            if is_x(nibble) then
                result(index) := 'X';
            else
                result(index) := HEX_DIGITS(to_integer(unsigned(nibble)) + 1);
            end if;
        end loop;

        return result;
    end function;

    -- Segnali di I/O della UUT
    signal REG_A : std_logic_vector(NBIT - 1 downto 0) := (others => '0');
    signal REG_B : std_logic_vector(NBIT - 1 downto 0) := (others => '0');
    signal CMD : aluOp := NOP;
    signal CLK : std_logic := '0';
    signal EN_MUL : std_logic := '0';
    signal RST : std_logic := '0';
    signal ALU_OUT : std_logic_vector(NBIT - 1 downto 0);

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

    component RCA_GEN is
        generic (
            DRCAS : time := 0 ns;
            DRCAC : time := 0 ns;
            NBIT : integer := (NBIT / (NBIT/2 ** RADIX)) -- Need to have NBIT / N_Co bits per adder
        );
        port (
            A : in std_logic_vector(NBIT - 1 downto 0);
            B : in std_logic_vector(NBIT - 1 downto 0);
            Ci : in std_logic;
            S : out std_logic_vector(NBIT - 1 downto 0);
            Co : out std_logic);
    end component;

    -- control signals from the encoder to the units
    signal S_MUX_OUT_SEL : std_logic_vector(1 downto 0); -- selection signal for the MUX which chooses the output of the correct unit
    signal S_MULT_EN : std_logic; -- Enables the Pipe registers of the Multiplier
    signal S_ADD_CIN : std_logic; -- Carry in of the add/sub (ADD_CIN = '0' --> ADD , ADD_CIN = '1' --> SUB)
    signal S_LOGIC_SEL : std_logic_vector (3 downto 0); -- Selects the correct logical operation
    signal S_COMP_SEL : std_logic_vector (2 downto 0); -- Selection signal for the comparator
    signal S_COMP_TYPE : std_logic; -- Signed( = '1') or unsigned ( = '0' )comparison --> it changes only for lower (<) comparison 
    signal S_SHIFT_CONFIG : std_logic_vector (1 downto 0); -- selects direction and type of the shift

    -- Carry signal reference generation
    signal Co_rca : std_logic_vector((NBIT/2 ** RADIX) downto 0) := (others => '0'); -- Signal with the carry generated by rca, has 1 more bit since index 0 is carryy in of the RCA
    
    signal REG_B_XOR : std_logic_vector(NBIT - 1 downto 0) := (others => '0');
    
    signal Co_reference : std_logic_vector((NBIT/2 ** RADIX) - 1 downto 0) := (others => '0'); -- Signal with the carry generated by a ripple adder for comparison, should match the Co of the DUT

begin

    -- Generate internal carry with a simple RCA to have a reference
    REG_B_XOR <= REG_B xor (REG_B'range => S_ADD_CIN);
    -- Map position zero  to cary in
    Co_rca(0) <= S_ADD_CIN;
    -- map rca to reference singals, the reference is assumed to be the correct value, should be equal to Co_tb
    Co_reference <= Co_rca((NBIT/2 ** RADIX) downto 1);

    rca_ref : for i in 0 to (NBIT/2 ** RADIX) - 1 generate -- Generate as many carry RCA as Co bits
        constant delta : integer := (NBIT / (NBIT/2 ** RADIX)); -- How many bits to advance at each adder
        rca_cmp : RCA_GEN port map(
            A => REG_A((i + 1) * delta - 1 downto i * delta),
            B => REG_B_XOR((i + 1) * delta - 1 downto i * delta),
            Ci => Co_rca(i),
            S => open,
            Co => Co_rca(i + 1)
        );
    end generate;

    -- Normal ALU definiton
    ENCODER_INST : ALU_ENCODER
    port map(
        CMD => CMD,
        MUX_OUT_SEL => S_MUX_OUT_SEL,
        MULT_EN => S_MULT_EN,
        ADD_CIN => S_ADD_CIN,
        LOGIC_SEL => S_LOGIC_SEL,
        COMP_SEL => S_COMP_SEL,
        COMP_TYPE => S_COMP_TYPE,
        SHIFT_CONFIG => S_SHIFT_CONFIG
    );
    -- Actual ALU component, performs computations, logicals and comparisons
    ALU_CMP : ALU_DBG
    generic map(
        NBIT => NBIT
    )
    port map(
        REG_A => REG_A,
        REG_B => REG_B,
        -- control signals coming from the encoder
        C_MUX_OUT_SEL => S_MUX_OUT_SEL,
        C_ADD_CIN => S_ADD_CIN,
        C_LOGIC_SEL => S_LOGIC_SEL,
        C_COMP_SEL => S_COMP_SEL,
        C_COMP_TYPE => S_COMP_TYPE,
        C_SHIFT_CONFIG => S_SHIFT_CONFIG,
        -- Output signal
        ALU_OUT => ALU_OUT
    );
    -- Generazione del segnale di Clock
    clk_process : process
    begin
        CLK <= '0';
        wait for CLK_PERIOD / 2;
        CLK <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Processo principale di Stimolo
    stim_proc : process
    begin
        -- 1. Inizializzazione e Reset Asincrono
        RST <= '0'; -- Reset attivo basso
        EN_MUL <= '0';
        REG_A <= (others => '0');
        REG_B <= (others => '0');
        CMD <= NOP;
        wait for CLK_PERIOD * 2;

        RST <= '1'; -- Rilascio del Reset
        wait until rising_edge(CLK);

        ------------------------------------------------------------------------
        -- TEST ADDER: tutti i risultati sono confrontati automaticamente
        ------------------------------------------------------------------------
        -- Valore neutro e operandi singoli
        REG_A <= x"00000000";
        REG_B <= x"00000000";
        CMD <= ADD;
        wait for CLK_PERIOD;
        if ALU_OUT /= x"00000000" then
            report "ERRORE: ADD 00000000 + 00000000 = 00000000, ma ottenuto " & slv_to_hex(ALU_OUT) severity error;
        end if;

        REG_A <= x"00000001";
        REG_B <= x"00000000";
        wait for CLK_PERIOD;
        if ALU_OUT /= x"00000001" then
            report "ERRORE: ADD 00000001 + 00000000 = 00000001, ma ottenuto " & slv_to_hex(ALU_OUT) severity error;
        end if;

        REG_A <= x"00000000";
        REG_B <= x"00000001";
        wait for CLK_PERIOD;
        if ALU_OUT /= x"00000001" then
            report "ERRORE: ADD 00000000 + 00000001 = 00000001, ma ottenuto " & slv_to_hex(ALU_OUT) severity error;
        end if;

        -- Operandi con bit di riporto consecutivi
        REG_A <= x"0000000F";
        REG_B <= x"00000001";
        wait for CLK_PERIOD;
        if ALU_OUT /= x"00000010" then
            report "ERRORE: ADD 0000000F + 00000001 = 00000010, ma ottenuto " & slv_to_hex(ALU_OUT) severity error;
        end if;

        REG_A <= x"0000FFFF";
        REG_B <= x"00000001";
        wait for CLK_PERIOD;
        if ALU_OUT /= x"00010000" then
            report "ERRORE: ADD 0000FFFF + 00000001 = 00010000, ma ottenuto " & slv_to_hex(ALU_OUT) severity error;
        end if;

        REG_A <= x"00FFFFFF";
        REG_B <= x"00000001";
        wait for CLK_PERIOD;
        if ALU_OUT /= x"01000000" then
            report "ERRORE: ADD 00FFFFFF + 00000001 = 01000000, ma ottenuto " & slv_to_hex(ALU_OUT) severity error;
        end if;

        -- Valori alternati e verifica di entrambi gli ingressi
        REG_A <= x"AAAAAAAA";
        REG_B <= x"55555555";
        wait for CLK_PERIOD;
        if ALU_OUT /= x"FFFFFFFF" then
            report "ERRORE: ADD AAAAAAAA + 55555555 = FFFFFFFF, ma ottenuto " & slv_to_hex(ALU_OUT) severity error;
        end if;

        REG_A <= x"12345678";
        REG_B <= x"87654321";
        wait for CLK_PERIOD;
        if ALU_OUT /= x"99999999" then
            report "ERRORE: ADD 12345678 + 87654321 = 99999999, ma ottenuto " & slv_to_hex(ALU_OUT) severity error;
        end if;

        -- Overflow oltre i 32 bit: si verifica il risultato modulo 2^32
        REG_A <= x"FFFFFFFF";
        REG_B <= x"00000001";
        wait for CLK_PERIOD;
        if ALU_OUT /= x"00000000" then
            report "ERRORE: ADD FFFFFFFF + 00000001 = 00000000, ma ottenuto " & slv_to_hex(ALU_OUT) severity error;
        end if;

        REG_A <= x"80000000";
        REG_B <= x"80000000";
        wait for CLK_PERIOD;
        if ALU_OUT /= x"00000000" then
            report "ERRORE: ADD 80000000 + 80000000 = 00000000, ma ottenuto " & slv_to_hex(ALU_OUT) severity error;
        end if;

        REG_A <= x"7FFFFFFF";
        REG_B <= x"00000001";
        wait for CLK_PERIOD;
        if ALU_OUT /= x"80000000" then
            report "ERRORE: ADD 7FFFFFFF + 00000001 = 80000000, ma ottenuto " & slv_to_hex(ALU_OUT) severity error;
        end if;
        -- Test case: 28 + (-20) = 8
        REG_A <= x"0000001C"; -- 28
        REG_B <= x"FFFFFFEC"; -- -20 (two's complement)
        wait for CLK_PERIOD;
        if ALU_OUT /= x"00000008" then
            report "ERRORE: ADD 0000001C + FFFFFFEC = 00000008, ma ottenuto " & slv_to_hex(ALU_OUT) severity error;
        end if;
        -- Test case: 16 - 1 = 15
        REG_A <= x"00000010"; -- 16
        REG_B <= x"00000001"; -- 1
        CMD <= SUB; -- Change operation to subtraction
        wait for CLK_PERIOD;
        if ALU_OUT /= x"0000000F" then
            report "ERRORE: SUB 00000010 - 00000001 = 0000000F, ma ottenuto " & slv_to_hex(ALU_OUT) severity error;
        end if;
        -- Fine simulazione
        report "Simulazione completata con successo!" severity note;
        wait;
    end process;

end architecture behavior;