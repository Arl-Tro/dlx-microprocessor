library IEEE;
use IEEE.std_logic_1164.all;
use WORK.constants.all;

entity CARRY_GENERATOR is
  generic (
    NBIT : integer := 32;
    NBIT_PER_BLOCK : integer := 4
  );
  port (
    A : in std_logic_vector(NBIT - 1 downto 0);
    B : in std_logic_vector(NBIT - 1 downto 0);
    Cin : in std_logic;
    Co : out std_logic_vector((NBIT / NBIT_PER_BLOCK) - 1 downto 0) -- Vector of the calculated carrys
  );
end entity;

architecture STRUCTURAL of CARRY_GENERATOR is

  -- Function that calculate the base 2 logaritm.(ex. 32 bit -> 5 stadi)
  function log2(n : integer) return integer is
    variable result, temp_value : integer;
  begin
    result := 0;
    temp_value := n;
    while temp_value > 1 loop
      temp_value := temp_value / 2;
      result := result + 1;
    end loop;
    return result;
  end function;

  -- Define how high is the tree
  constant N_LEVELS : integer := log2(NBIT);

  -- Matrix with N_LEVEL+1 rows and NBIT+1 colums. Position (0,0) dedicated to the special case g=Cin and p=0
  type SignalVector is array (NBIT downto 0) of std_logic_vector(NBIT downto 0);
  signal g_mat : SignalVector; -- Matrix of GENERATE 
  signal p_mat : SignalVector; -- Matrix of PROPAGATE 
  -- omponent G: Calcolate the carry using the current Generate and current Propagate with the previous carry 
  component G
    port (
      G_ik : in std_logic;
      P_ik : in std_logic;
      G_k_1j : in std_logic;
      G_ij : out std_logic);
  end component;

  -- Component PG: Calcolate the new Generate and the new Propagate for the next step
  component PG
    port (
      G_ik : in std_logic; -- G_{i}:{k}
      P_ik : in std_logic; -- P_{i}:{k}
      G_k_1j : in std_logic; -- G_{k-1}:{j}
      P_k_1j : in std_logic; -- P_{k-1}:{j}
      G_ij : out std_logic; -- Out G
      P_ij : out std_logic -- Out P
    );
  end component;

begin
  -- NOTE: all the thinking about indexing the p/g matrices is done starting from index 1, since index 0 was reserved for the carry in
  -- First bit p/g first layer
  g_mat(0)(0) <= Cin;
  p_mat(0)(0) <= '0';
  -- First, generate the input p/g
  GEN_FIRST_ROW : for i in 0 to NBIT - 1 generate
    g_mat(i + 1)(i + 1) <= A(i) and B(i);
    p_mat(i + 1)(i + 1) <= A(i) xor B(i);
  end generate GEN_FIRST_ROW;

  -- Link the carry
  CARRY_G0 : component G
    port map(
      G_ik => g_mat(1)(1), 
      P_ik => p_mat(1)(1), 
      G_k_1j => g_mat(0)(0), -- Cin
      G_ij => g_mat(1)(0) -- Carry out of bit 0 (G_1:0)
    );

    -- First thing, handle the carry in
    -- Split the generation in 2 steps, first the RADIX 4 grouping then the generation of the carries each 4 bits

    GEN_STEP_1 : for i in 0 to (N_LEVELS / 2) generate
      constant current_step : integer := 2 ** (i + 1);
    begin
      GEN_ROW_1 : for j in current_step to NBIT generate
        constant pg_i : integer := j; -- I know, the naming is not the best...
        constant pg_k : integer := (pg_i - (current_step / 2)) + 1; -- the pg_i/j/k reflect the standard pg network nomenclature where i >= k > j
        constant pg_j : integer := (pg_i - current_step) + 1;
      begin

        STEP_FILTER : if (j mod current_step = 0) generate -- Only generate each current_step delta
          -- The first iteration, there is a G block, the others are PG
          FIRST_POSITION : if (j = current_step) generate
            G_TOP : G port map(
              G_ik => g_mat(pg_i)(pg_k),
              P_ik => p_mat(pg_i)(pg_k),
              G_k_1j => g_mat(pg_k - 1)(0),
              G_ij => g_mat(pg_i)(0)
            );
          end generate FIRST_POSITION;
          -- The others are PG blocks
          NON_FIRST_POSITION : if (j /= current_step) generate
            PG_TOP : PG port map(
              G_ik => g_mat(pg_i)(pg_k),
              P_ik => p_mat(pg_i)(pg_k),
              G_k_1j => g_mat(pg_k - 1)(pg_j),
              P_k_1j => p_mat(pg_k - 1)(pg_j),
              G_ij => g_mat(pg_i)(pg_j),
              P_ij => p_mat(pg_i)(pg_j)
            );
          end generate;

        end generate;
      end generate GEN_ROW_1;
    end generate GEN_STEP_1;

    GEN_STEP_2 : for i in 0 to (N_LEVELS / 2) - 1 generate
      constant block_size : integer := 2 ** (i + 1); -- How many PGs in a block?
      constant block_jump : integer := 4; -- How many bits between successive parts of a block
      constant block_delta : integer := block_jump * block_size * 2; -- How far are blocks between them?
      constant iterations : integer := ((NBIT/block_jump) / block_size)/2 - 1;
    begin
      HOR_MOVE : for j in 0 to iterations generate -- Each row has 4 blocks
        constant start : integer := NBIT - j * block_delta;
      begin
        GEN_BLOCK : for k in 0 to block_size - 1 generate
          constant pg_i : integer := start - k * block_jump;
          constant pg_j : integer := start - block_delta + 1;
          constant pg_k : integer := start - (block_delta/2) + 1;

        begin
          LAST_POSITION : if (j = iterations) generate
            G_TOP : G port map(
              G_ik => g_mat(pg_i)(pg_k),
              P_ik => p_mat(pg_i)(pg_k),
              G_k_1j => g_mat(pg_k - 1)(0),
              G_ij => g_mat(pg_i)(0)
            );
          end generate LAST_POSITION;
          -- The others are PG blocks
          NON_LAST_POSITION : if (j /= iterations) generate
            PG_TOP : PG port map(
              G_ik => g_mat(pg_i)(pg_k),
              P_ik => p_mat(pg_i)(pg_k),
              G_k_1j => g_mat(pg_k - 1)(pg_j),
              P_k_1j => p_mat(pg_k - 1)(pg_j),
              G_ij => g_mat(pg_i)(pg_j),
              P_ij => p_mat(pg_i)(pg_j)
            );
          end generate NON_LAST_POSITION;

        end generate GEN_BLOCK;

      end generate HOR_MOVE;

    end generate GEN_STEP_2;

    -- Export the carry generated at the end of every block.
    GEN_CARRY_OUTPUTS : for i in 0 to (NBIT / NBIT_PER_BLOCK) - 1 generate
    begin
      Co(i) <= g_mat((i + 1) * NBIT_PER_BLOCK)(0);
    end generate GEN_CARRY_OUTPUTS;
  end architecture;

  configuration CFG_CARRY_GENERATOR_STRUCTURAL of CARRY_GENERATOR is
    for STRUCTURAL
    end for;
  end configuration;