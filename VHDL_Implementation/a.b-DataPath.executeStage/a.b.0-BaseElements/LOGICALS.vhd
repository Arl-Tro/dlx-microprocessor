library IEEE;
use ieee.std_logic_1164.all;
use WORK.constants.all;
use ieee.numeric_std.all;

-- This entity performs logic operation. It is based on the T2 'logicals' unit

-- S0 S1 S2 S3      Operation
-- 0  0  0  0       AND
-- 1  1  1  0       NAND
-- 0  1  1  1       OR
-- 1  0  0  0       NOR
-- 0  1  1  0       XOR
-- 1  0  0  1       XNOR

entity LOGICALS is
	generic ( 
        NBIT : integer := numBit
		);
	port(
		S : in std_logic_vector(3 downto 0);
		R1 : in std_logic_vector(NBIT-1 downto 0);
		R2 : in std_logic_vector(NBIT-1 downto 0);
		LOUT : out std_logic_vector(NBIT-1 downto 0)
	);
end entity LOGICALS;

-- PORTS EXPLANATION

--S --> selection signal used to select the type of operation 
--R1, R2 --> input operands
--LOUT --> output result

architecture STRUCT of LOGICALS is

signal L0 , L1, L2, L3 : std_logic_vector(NBIT-1 downto 0);
--These are intermediate signals used to connect the two layers of NAND gates

begin


NAND_FIRST_LAYER : for i in 0 to NBIT-1 generate 
	L0(i) <= not((not(R1(i))) and (not(R2(i))) and S(0));
	L1(i) <= not((not(R1(i))) and R2(i) and S(1));
	L2(i) <= not(R1(i) and (not(R2(i))) and S(2));
	L3(i) <= not(R1(i) and R2(i) and S(3));
end generate NAND_FIRST_LAYER;

-- NAND_SECOND_LAYER
LOUT <= not (L0 and L1 and L2 and L3);

end architecture STRUCT;
