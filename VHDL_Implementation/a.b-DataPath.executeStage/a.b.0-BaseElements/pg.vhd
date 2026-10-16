library IEEE;
use IEEE.std_logic_1164.all; 
use WORK.constants.all;

entity PG is
    port (
        G_ik  : in  std_logic; -- G_{i}:{k}
        P_ik  : in  std_logic; -- P_{i}:{k}
        G_k_1j: in  std_logic; -- G_{k-1}:{j}
        P_k_1j: in  std_logic; -- P_{k-1}:{j}
        G_ij  : out std_logic; -- Out G
        P_ij  : out std_logic  -- Out P
    );
end PG;

architecture BEHAVIORAL of PG is
  
begin
    G_ij <= G_ik or (P_ik and G_k_1j);
    P_ij <= P_ik and P_k_1j;
end BEHAVIORAL;

configuration CFG_PG_BEHAVIORAL of PG is
	for BEHAVIORAL
	end for;
end CFG_PG_BEHAVIORAL;
