library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use WORK.constants.all;

entity register_file_windowed is
    generic (
        NBIT : integer := NumBit; -- bit width of each register (e.g., 32 bits)
        NBIT_ADDR : integer := NumBit_add; -- bits to address virtual registers (e.g., 5 bits = 32 registers)
        M : integer := GloReg; -- number of global registers
        N : integer := NumRegBlock; -- number of registers per IN, LOCAL, or OUT block
        F : integer := NumWin -- total number of physical windows
    );
    port (
        CLK : in std_logic; -- Clock for all register-file, window-management, and memory-transfer state updates
        RESET : in std_logic; -- Active-high synchronous reset that returns the register file to its initial window
        ENABLE : in std_logic; -- Enables normal accesses and window-management operations when high

        -- pipeline Read/Write interface (NORMAL mode)
        RD1 : in std_logic; -- Enables reading the register selected by ADD_RD1 into OUT1
        RD2 : in std_logic; -- Enables reading the register selected by ADD_RD2 into OUT2
        WR : in std_logic; -- Enables writing DATAIN to the register selected by ADD_WR
        ADD_WR : in std_logic_vector(NBIT_ADDR - 1 downto 0); -- Virtual address of the register to write
        ADD_RD1 : in std_logic_vector(NBIT_ADDR - 1 downto 0); -- Virtual address of the register read through port 1
        ADD_RD2 : in std_logic_vector(NBIT_ADDR - 1 downto 0); -- Virtual address of the register read through port 2
        DATAIN : in std_logic_vector(NBIT - 1 downto 0); -- Data written to the register selected by ADD_WR
        OUT1 : out std_logic_vector(NBIT - 1 downto 0); -- Data read from the virtual register selected by ADD_RD1
        OUT2 : out std_logic_vector(NBIT - 1 downto 0); -- Data read from the virtual register selected by ADD_RD2

        -- subroutine control signals
        CALL : in std_logic; -- Requests a window advance for a subroutine call; may trigger a spill when no window is free
        RETURN_S : in std_logic; -- Requests a window restore for a subroutine return; may trigger a fill when no window is available

        -- pipeline stall requests
        SPILL : out std_logic; -- High while the current register window is being saved to memory; stalls the pipeline
        FILL : out std_logic; -- High while a register window is being restored from memory; stalls the pipeline

        -- direct memory interface 
        MEM_ADDR : out std_logic_vector(NBIT - 1 downto 0); -- Stack-memory address for the active spill or fill transfer
        DATA_TO_MEM : out std_logic_vector(NBIT - 1 downto 0); -- Register-window word written to memory during a spill
        DATA_FROM_MEM : in std_logic_vector(NBIT - 1 downto 0); -- Register data read back from memory during a fill operation
        MEM_ACK : in std_logic -- Indicates that the current memory transfer has completed
    );
end register_file_windowed;

architecture behavioral of register_file_windowed is

    -- total physical register array size: F windows * 2 blocks (IN + LOCAL) + M globals
    constant RF_SIZE : integer := (F * 2 * N) + M;

    subtype REG_ADDR is natural range 0 to RF_SIZE - 1;
    type REG_ARRAY is array(REG_ADDR) of std_logic_vector(NBIT - 1 downto 0);
    signal REGISTERS : REG_ARRAY;

    signal CWP : integer range 0 to F - 1; -- current Window Pointer
    signal SWP : integer range 0 to F - 1; -- saved Window Pointer (oldest window saved in memory)
    signal CANSAVE : integer range 0 to F; -- number of available free windows
    signal CANRESTORE : integer range 0 to F; -- number of active restoreable windows in the RF

    signal SPILL_CNT : integer range 0 to 2 * N - 1; -- register counter during Spill
    signal FILL_CNT : integer range 0 to 2 * N - 1; -- register counter during Fill

    type FSM_STATE is (NORMAL, SPILLING, FILLING);
    signal STATE : FSM_STATE;

    -- internal stack pointer register used for memory addressing during Spill/Fill operations
    signal SP_REG : unsigned(NBIT - 1 downto 0);

    -- translates virtual addresses into physical RF array indices
    function virt_to_phys_addr(vaddr : integer; cwp_v : integer) return integer is
        variable phys_addr : integer;
    begin
        if vaddr < N then
            phys_addr := cwp_v * 2 * N + vaddr; -- IN Block
        elsif vaddr < 2 * N then
            phys_addr := cwp_v * 2 * N + vaddr; -- LOCAL Block
        elsif vaddr < 3 * N then
            phys_addr := ((cwp_v + 1) mod F) * 2 * N + (vaddr - 2 * N); -- OUT Block (shared with next IN)
        else
            phys_addr := F * 2 * N + (vaddr - 3 * N); -- GLOBAL Block
        end if;
        return phys_addr;
    end function;

begin

    MEM_ADDR <= std_logic_vector(SP_REG);

    -- Read operation must be kept asynchronous to not lose an extra clock cycle
    -- The problem with fill/spill does not exist since a stall will be commanded anyway
    -- Internal forwarding implemented
    READ_PROC_RD1 : process (RD1, ADD_RD1, WR, ADD_WR, DATAIN, REGISTERS, CWP)
        variable addr_rd1 : integer;
        variable addr_rw : integer;
    begin
        addr_rd1 := virt_to_phys_addr(to_integer(unsigned(ADD_RD1)), CWP);
        addr_rw := virt_to_phys_addr(to_integer(unsigned(ADD_WR)), CWP);

        if RD1 = '1' then
            -- Internal Bypass: If writing and reading the same register in the same cycle
            if (WR = '1') and (addr_rd1 = addr_rw) and (to_integer(unsigned(ADD_RD1)) /= 0) then
                OUT1 <= DATAIN;
            else
                OUT1 <= REGISTERS(addr_rd1);
            end if;
        else
            OUT1 <= (others => '0');
        end if;
    end process;

    READ_PROC_RD2 : process (RD2, ADD_RD2, WR, ADD_WR, DATAIN, REGISTERS, CWP)
        variable addr_RD2 : integer;
        variable addr_rw : integer;
    begin
        addr_RD2 := virt_to_phys_addr(to_integer(unsigned(ADD_RD2)), CWP);
        addr_rw := virt_to_phys_addr(to_integer(unsigned(ADD_WR)), CWP);

        if RD2 = '1' then
            -- Internal Bypass: If writing and reading the same register in the same cycle
            if (WR = '1') and (addr_RD2 = addr_rw) and (to_integer(unsigned(ADD_RD2)) /= 0) then
                OUT2 <= DATAIN;
            else
                OUT2 <= REGISTERS(addr_RD2);
            end if;
        else
            OUT2 <= (others => '0');
        end if;
    end process;

    WRITE_PROC : process (CLK)
        variable addr_wr, addr_rd1, addr_rd2 : integer;
    begin
        if rising_edge(CLK) then
            if RESET = '1' then
                STATE <= NORMAL;
                CWP <= 0;
                SWP <= 0;
                CANSAVE <= F - 1;
                CANRESTORE <= 0;
                SPILL_CNT <= 0;
                FILL_CNT <= 0;
                SPILL <= '0';
                FILL <= '0';
                DATA_TO_MEM <= (others => '0');
                -- OUT1 <= (others => '0');
                -- OUT2 <= (others => '0');
                SP_REG <= (others => '0');

                for i in 0 to RF_SIZE - 1 loop
                    REGISTERS(i) <= (others => '0');
                end loop;

            elsif ENABLE = '1' then
                case STATE is

                    when NORMAL =>
                        SPILL <= '0';
                        FILL <= '0';

                        if CALL = '1' then
                            if CANSAVE > 0 then
                                CWP <= (CWP + 1) mod F;
                                CANSAVE <= CANSAVE - 1;
                                CANRESTORE <= CANRESTORE + 1;
                            else
                                -- window overflow: Trigger Spill without advancing CWP 
                                STATE <= SPILLING;
                                SPILL <= '1';
                                SPILL_CNT <= 0;
                            end if;

                        elsif RETURN_S = '1' then
                            if CANRESTORE > 0 then
                                CWP <= (CWP - 1 + F) mod F;
                                CANRESTORE <= CANRESTORE - 1;
                                CANSAVE <= CANSAVE + 1;
                            else
                                -- window underflow: trigger Fill
                                STATE <= FILLING;
                                FILL <= '1';
                                FILL_CNT <= 0;
                            end if;

                        else
                            -- standard pipeline Read/Write access
                            addr_wr := virt_to_phys_addr(to_integer(unsigned(ADD_WR)), CWP);
                            -- addr_rd1 := virt_to_phys_addr(to_integer(unsigned(ADD_RD1)), CWP);
                            -- addr_rd2 := virt_to_phys_addr(to_integer(unsigned(ADD_RD2)), CWP);

                            if WR = '1' then
                                REGISTERS(addr_wr) <= DATAIN;
                            end if;
                            -- if RD1 = '1' then
                            --     OUT1 <= REGISTERS(addr_rd1);
                            -- end if;
                            -- if RD2 = '1' then
                            --     OUT2 <= REGISTERS(addr_rd2);
                            -- end if;
                        end if;

                    when SPILLING =>
                        SPILL <= '1';
                        DATA_TO_MEM <= REGISTERS(SWP * 2 * N + SPILL_CNT);

                        if MEM_ACK = '1' then
                            if SPILL_CNT = (2 * N) - 1 then
                                -- completed spilling the current window to memory
                                SWP <= (SWP + 1) mod F;
                                CWP <= (CWP + 1) mod F;
                                SPILL_CNT <= 0;
                                STATE <= NORMAL;
                                SPILL <= '0';
                                SP_REG <= SP_REG + 4;
                            else
                                SPILL_CNT <= SPILL_CNT + 1;
                                SP_REG <= SP_REG + 4; -- increment Stack Pointer (4-byte word offset)
                            end if;
                        end if;

                    when FILLING =>
                        FILL <= '1';

                        if MEM_ACK = '1' then
                            -- write memory data back into the restored window registers
                            REGISTERS(((SWP - 1 + F) mod F) * 2 * N + FILL_CNT) <= DATA_FROM_MEM;

                            if FILL_CNT = (2 * N) - 1 then
                                -- completed filling the window from memory
                                SWP <= (SWP - 1 + F) mod F;
                                CWP <= (CWP - 1 + F) mod F; -- switch back to restored window
                                FILL_CNT <= 0;
                                STATE <= NORMAL;
                                FILL <= '0';
                                SP_REG <= SP_REG - 4;
                            else
                                FILL_CNT <= FILL_CNT + 1;
                                SP_REG <= SP_REG - 4; -- decrement Stack Pointer
                            end if;
                        end if;

                end case;
            end if;
        end if;
    end process;

end behavioral;

configuration CFG_RFW_BEH of register_file_windowed is
    for behavioral
    end for;
end configuration;