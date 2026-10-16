library IEEE;
use IEEE.std_logic_1164.all; --  libreria IEEE con definizione tipi standard logic
use WORK.constants.all; -- libreria WORK user-defined

entity G is
    port (
        G_ik  : in  std_logic; -- G_{i}:{k}
        P_ik  : in  std_logic; -- P_{i}:{k}
        G_k_1j: in  std_logic; -- G_{k-1}:{j}
        G_ij  : out std_logic -- Out G_{i}:{j}
    );
end G;

architecture BEHAVIORAL of G is
  
begin
    G_ij <= G_ik or (P_ik and G_k_1j);
end BEHAVIORAL;

configuration CFG_G_BEHAVIORAL of G is
	for BEHAVIORAL
	end for;
end CFG_G_BEHAVIORAL;
