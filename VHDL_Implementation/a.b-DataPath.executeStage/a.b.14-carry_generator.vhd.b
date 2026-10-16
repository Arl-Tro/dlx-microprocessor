library IEEE;
  use IEEE.std_logic_1164.all;
  use WORK.constants.all;

entity CARRY_GENERATOR is
  generic (
    NBIT           : integer := 32;
    NBIT_PER_BLOCK : integer := 4
  );
  port (
    A   : in  std_logic_vector(NBIT - 1 downto 0);
    B   : in  std_logic_vector(NBIT - 1 downto 0);
    Cin : in  std_logic;
    Co  : out std_logic_vector((NBIT / NBIT_PER_BLOCK) - 1 downto 0) -- Vector of the calculated carrys
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
  type SignalVector is array (0 to N_LEVELS) of std_logic_vector(NBIT downto 0);
  signal g0 : SignalVector; -- Matrix of GENERATE 
  signal p : SignalVector; -- Matrix of PROPAGATE 


  -- omponent G: Calcolate the carry using the current Generate and current Propagate with the previous carry 
  component G
    port (G_ik   : in  std_logic;
          P_ik   : in  std_logic;
          G_k_1j : in  std_logic;
          G_ij   : out std_logic);
  end component;

  -- Component PG: Calcolate the new Generate and the new Propagate for the next step
  component PG
    port (G_ik   : in  std_logic;
          P_ik   : in  std_logic;
          G_k_1j : in  std_logic;
          P_k_1j : in  std_logic;
          G_ij   : out std_logic;
          P_ij   : out std_logic);
  end component;

begin

   -- caso speciale g0 = CIN, p0 = 0 
  g0(0)(0) <= Cin;
  p(0)(0) <= '0';

g0(0)(1) <= (A(0) and B(0)) or ((A(0) xor B(0)) and Cin); 
p(0)(1)  <= '0'; 

  -- genero il pg_network
  PG_NETWORK: for i in 2 to NBIT generate
    g0(0)(i) <= A(i - 1) and B(i - 1)  ;
    p(0)(i) <= A(i - 1) xor B(i - 1);
  end generate;

  LOOP_LEVELS: for i in 1 to N_LEVELS generate
    constant step_current : integer := 2 ** i;       --livello corrente -> (2, 4, 8, 16...)
    constant step_prev    : integer := 2 ** (i - 1); --livello precedente -> (1, 2, 4, 8...)
-- 2 different parts of the levels
    constant division	  : integer := log2(NBIT_PER_BLOCK) + 1;
  begin

    
 

  -- costrisco lo Sparse Tree

      FIRST_PART : if (i <= division ) generate
	    LOOP_BITS_1 : for j in 0 to NBIT generate 
		
        -- stampa l'unico blocco G, che sarÃ  nella posizione dello step_current
        	FIRST_COL: if (j = step_current ) generate
          	    G_INST: G
            		port map (
              			G_ik   => g0(i - 1)(j),
              			P_ik   => p(i - 1)(j),
              			G_k_1j => g0(i - 1)(j - step_prev) ,
             			G_ij   => g0(i)(j)
            		);
          		p(i)(j) <= p(i - 1)(j);
        	end generate FIRST_COL;
		

        -- genero i blocchi PG

        	OTHER_COLS: if ((j > step_current) and ((j mod step_current) = 0)) generate
          			PG_INST: PG
            				port map (
              				G_ik   => g0(i - 1)(j),
              				P_ik   => p(i - 1)(j),
             				G_k_1j => g0(i - 1)(j - step_prev), -- Prende il riporto dal blocco precedente nello stadio i-1
             				P_k_1j => p(i - 1)(j - step_prev),
              				G_ij   => g0(i)(j),
              				P_ij   => p(i)(j)
           			);
      		end generate OTHER_COLS;
	  
	    PROP_VAL: if (j =0 or (j mod step_current /= 0)) generate
        	g0(i)(j) <= g0(i - 1)(j);
        	p(i)(j) <= p(i - 1)(j);
              end generate PROP_VAL;
            end generate LOOP_BITS_1;
        end generate FIRST_PART;


	SECOND_PART : if (i > division) generate
		COLUNMS : for k in 0 to NBIT generate
			FIRST_HALF : if (k <= step_current) generate
				IF1 : if (k > step_prev) generate
					G_BLOCK_IF_2 : if (k mod NBIT_PER_BLOCK = 0) generate
          					G_INST_1: G
            					port map (
              						G_ik   => g0(i - 1)(k),
              						P_ik   => p(i - 1)(k),
              						G_k_1j => g0(i - 1)(k - step_prev),
             						G_ij   => g0(i)(k)
            					);
          					p(i)(k) <= p(i - 1)(k);
        				end generate G_BLOCK_IF_2;
				end generate IF1;


                                ELSE_PROP : if (k<=step_prev or ( k mod NBIT_PER_BLOCK /= 0)) generate
                                     g0(i)(k) <= g0(i - 1)(k);
                                     p(i)(k) <= p(i - 1)(k);
                                end generate ELSE_PROP;
			end generate FIRST_HALF;



      
			SECOND_HALF :if (k > step_current) generate
				IF2 : if (k > (step_prev + step_current)) generate
					PG_BLOCK_IF_2 : if (k mod NBIT_PER_BLOCK = 0) generate
          					PG_INST_1: PG
            					port map (
              						G_ik   => g0(i - 1)(k),
              						P_ik   => p(i - 1)(k),
             						G_k_1j => g0(i - 1)(k - step_prev), 
             						P_k_1j => p(i - 1)(k - step_prev),
              						G_ij   => g0(i)(k),
              						P_ij   => p(i)(k)
           					);
        				end generate PG_BLOCK_IF_2;
				end generate IF2;
                                ELSE_PROP1 : if(k<= (step_prev + step_current ) or k mod NBIT_PER_BLOCK /=0 ) generate
                                         g0(i)(k) <= g0(i - 1)(k);
                                  p(i)(k) <= p(i - 1)(k);
                                end generate ELSE_PROP1;
			end generate SECOND_HALF;
		
	
	

      --se i dati non vengono dai blocchi G e PG li propago cosi da averli disponibili alla fine
                       -- PROP_VAL_1: if (k = 0 or (k mod NBIT_PER_BLOCK /= 0)) generate
                         -- g0(i)(k) <= g0(i - 1)(k);
                         -- p(i)(k) <= p(i - 1)(k);
                       -- end generate PROP_VAL_1;
                end generate COLUNMS;
   
        end generate SECOND_PART;
end generate LOOP_LEVELS;
  --prendo i carry dalla posizione 4 a 32
  CARRY_OUT: for l in 1 to ((NBIT / NBIT_PER_BLOCK)) generate
    Co(l-1) <= g0(N_LEVELS)(l * NBIT_PER_BLOCK);
  end generate;

end architecture;

configuration CFG_CARRY_GENERATOR_STRUCTURAL of CARRY_GENERATOR is
  for STRUCTURAL
  end for;
end configuration;
