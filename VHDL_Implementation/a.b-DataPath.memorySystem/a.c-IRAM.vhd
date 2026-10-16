library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use std.textio.all;
use ieee.std_logic_textio.all;
-- Instruction memory for DLX
-- Memory filled by a process which reads from a file
-- file name is "test.asm.mem"
entity IRAM is
  generic (
    RAM_DEPTH : integer := 256;
    I_SIZE : integer := 32);
  port (
    Rst : in std_logic;
    Addr : in std_logic_vector(I_SIZE - 1 downto 0);
    Dout : out std_logic_vector(I_SIZE - 1 downto 0)
  );

end IRAM;

architecture IRam_Bhe of IRAM is

  type RAMtype is array (0 to RAM_DEPTH - 1) of integer;-- std_logic_vector(I_SIZE - 1 downto 0);

  signal IRAM_mem : RAMtype := (others => 0);
  signal AddrByte : std_logic_vector(I_SIZE - 3 downto 0); -- Address with the 2 LSBs removed, this is done since the memory is only accessible in 32 bit words
begin -- IRam_Bhe

  AddrByte <= Addr(I_SIZE - 1 downto 2);
  Dout <= conv_std_logic_vector(IRAM_mem(conv_integer(unsigned(Addr(I_SIZE - 1 downto 2)))), I_SIZE);

  -- purpose: This process is in charge of filling the Instruction RAM with the firmware
  -- type   : combinational
  -- inputs : Rst
  -- outputs: IRAM_mem
  FILL_MEM_P : process (Rst)
    file mem_fp : text;
    variable file_line : line;
    variable index : integer := 0;
    variable tmp_data_u : std_logic_vector(I_SIZE - 1 downto 0);
  begin -- process FILL_MEM_P
    if (Rst = '0') then
      report "Loading instruction memory from ./iram.mem" severity note;
      file_open(mem_fp, "./build/iram.mem", READ_MODE);
      while (not endfile(mem_fp)) loop
        readline(mem_fp, file_line);
        hread(file_line, tmp_data_u);
        assert index < RAM_DEPTH
        report "IRAM file contains more words than the configured RAM depth at index: " & integer'image(index)
          severity failure;
        IRAM_mem(index) <= conv_integer(unsigned(tmp_data_u));
        index := index + 1;
      end loop;
      file_close(mem_fp);
      report "Instruction memory load complete" severity note;
    end if;
  end process FILL_MEM_P;

end IRam_Bhe;