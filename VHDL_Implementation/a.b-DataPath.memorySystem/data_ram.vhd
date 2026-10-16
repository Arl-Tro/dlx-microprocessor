library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.myTypes.all;
use work.cpu_32b_types.all;

entity data_ram is
    generic (
        ADDR_BUS_SIZE : integer := 32; -- width of the memory address bus
        DATA_BUS_SIZE : integer := 32; -- width of the data bus
        RAM_DEPTH : integer := 1024; -- total number of 32-bit words (4 KB)
        SERIAL_ADDR : integer := 65280 -- A write here will print on screen in vsim, remove for synthesis
    );
    port (
        CLK : in std_logic;
        RESET : in std_logic;
        ENABLE : in std_logic;
        READ_ENABLE : in std_logic; -- read  from arbiter
        WRITE_ENABLE : in std_logic_vector(3 downto 0); -- write from arbiter, bit 0 enables the write to bits 0-7 of the current RAM word, bit 1 8-15 ecc.
        ADDR : in std_logic_vector(ADDR_BUS_SIZE - 1 downto 0);
        DATA_IN : in std_logic_vector(DATA_BUS_SIZE - 1 downto 0);
        DATA_OUT : out std_logic_vector(DATA_BUS_SIZE - 1 downto 0)
    );
end data_ram;

architecture behavioral of data_ram is

    type RAM_TYPE is array (0 to RAM_DEPTH - 1) of std_logic_vector(DATA_BUS_SIZE - 1 downto 0);
    signal MEMORY : RAM_TYPE := (others => (others => '0'));

begin

    PROCESS_DRAM : process (CLK)
        variable word_addr : integer;
        constant serial_addr_div : integer := SERIAL_ADDR /4; -- Since the address gets /4
    begin
        if rising_edge(CLK) then
            if RESET = '1' then
                DATA_OUT <= (others => '0');

            elsif ENABLE = '1' then
                -- byte-address to word index (ADDR / 4)
                word_addr := to_integer(unsigned(ADDR(ADDR_BUS_SIZE - 1 downto 2)));

                if word_addr /= serial_addr_div then
                    -- synchronous write operation (used in SW / SPILL)
                    if WRITE_ENABLE(3) = '1' then
                        MEMORY(word_addr)(31 downto 24) <= DATA_IN(31 downto 24);
                    end if;
                    if WRITE_ENABLE(2) = '1' then
                        MEMORY(word_addr)(23 downto 16) <= DATA_IN(23 downto 16);
                    end if;
                    if WRITE_ENABLE(1) = '1' then
                        MEMORY(word_addr)(15 downto 8) <= DATA_IN(15 downto 8);
                    end if;
                    if WRITE_ENABLE(0) = '1' then
                        MEMORY(word_addr)(7 downto 0) <= DATA_IN(7 downto 0);
                    end if;
                else
                    if WRITE_ENABLE = "1111" then
                        assert false
                        report "DLX VALUE (Unigned/Signed): " & integer'image(to_integer(unsigned(DATA_IN))) & "/" & integer'image(to_integer(signed(DATA_IN)))
                            severity failure;
                    end if;
                end if;

                -- synchronous read operation (used in LW / FILL)
                if READ_ENABLE = '1' then
                    DATA_OUT <= MEMORY(word_addr);
                end if;
            end if;
        end if;
    end process PROCESS_DRAM;

end behavioral;