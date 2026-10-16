library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.constants.all;

entity RCA_GEN is
  generic (DRCAS : time := 0 ns;
                           DRCAC : time := 0 ns;
                           NBIT : integer := 8);
  port (
    A : in std_logic_vector(NBIT - 1 downto 0);
    B : in std_logic_vector(NBIT - 1 downto 0);
    Ci : in std_logic;
    S : out std_logic_vector(NBIT - 1 downto 0);
    Co : out std_logic);
end RCA_GEN;

architecture STRUCTURAL of RCA_GEN is

  signal STMP : std_logic_vector(NBIT - 1 downto 0);
  signal CTMP : std_logic_vector(NBIT downto 0);

  component FA
    generic (
      DFAS : time := 0 ns;
      DFAC : time := 0 ns);
    port (
      A : in std_logic;
      B : in std_logic;
      Ci : in std_logic;
      S : out std_logic;
      Co : out std_logic);
  end component;

begin

  CTMP(0) <= Ci;
  S <= STMP;
  Co <= CTMP(NBIT);

  ADDER1 : for I in 1 to NBIT generate
    FAI : FA
    generic map(DFAS => DRCAS, DFAC => DRCAC)
    port map(A(I - 1), B(I - 1), CTMP(I - 1), STMP(I - 1), CTMP(I));
  end generate;

end STRUCTURAL;

architecture BEHAVIORAL of RCA_GEN is
  signal TMP : std_logic_vector(NBIT downto 0);
begin

  TMP <= ('0' & A) + ('0' & B) + Ci;

  S <= TMP(NBIT - 1 downto 0);
  Co <= TMP(NBIT);
end BEHAVIORAL;

configuration CFG_RCA_GEN_STRUCTURAL of RCA_GEN is
  for STRUCTURAL
    for ADDER1
      for all : FA
        use configuration WORK.CFG_FA_BEHAVIORAL;
      end for;
    end for;
  end for;
end CFG_RCA_GEN_STRUCTURAL;

configuration CFG_RCA_GEN_BEHAVIORAL of RCA_GEN is
  for BEHAVIORAL
  end for;
end CFG_RCA_GEN_BEHAVIORAL;