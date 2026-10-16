library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
use ieee.std_logic_arith.all;
use work.myTypes.all;

entity EQ_ZERO is
    generic (
        NBIT : natural := 32
    );
    port (
        D : in std_logic_vector (NBIT - 1 downto 0); -- Input data
        EZ : out std_logic -- Will be '1' if D is 0 or '0' if it is not (Equal Zero)
    );
end entity;

architecture STRUCTURAL of EQ_ZERO is
    signal partial_rslt : std_logic_vector(NBIT  downto 0);

    component OR2
        port (
            A : in std_logic;
            B : in std_logic;
            Y : out std_logic
        );
    end component;

    component INV is
        port (
            A : in std_logic;
            Y : out std_logic
        );
    end component;

begin

    OR_LAYER : for i in 0 to NBIT - 1 generate
        OR_PORT : component OR2
            port map(
                A => D(i),
                B => partial_rslt(i),
                Y => partial_rslt(i + 1)
            );

        end generate OR_LAYER;

        partial_rslt(0) <= '0';

        OUT_INVERTER : component INV port map(
            A => partial_rslt(NBIT),
            Y => EZ
        );
    end architecture;

    -- architecture STRUCURAL of EQ_ZERO is
    --     component NAND_GEN 
    --         generic (
    --             NBITS : integer := 4  -- Numero di ingressi (predefinito a 4)
    --         );
    --         port (
    --             A : in  std_logic_vector(NBITS - 1 downto 0);
    --             Y : out std_logic
    --         );
    --     end component;

    --     component XOR_2
    --         port(
    -- 		    A : in std_logic;
    -- 		    B : in std_logic;
    -- 		    Y : out std_logic
    -- 	    );
    --     end component;
    --     constant ZERO : std_logic_vector (NBIT - 1 downto 0) := (others => '0');
    --     signal XOR_RES : std_logic_vector (NBIT -1 downto 0);
    --     begin
    --     XOR_LAYER : for i in 0  to NBIT -1 generate
    --         XOR_INST : XOR_2
    --             port map(
    -- 		        A => D(i),
    -- 		        B => ZERO(i),
    -- 		        Y => XOR_RES(i)
    -- 	    );

    --     end generate XOR_LAYER;
    --     NAND_INST : NAND_GEN
    --         generic map(
    --             NBITS => NBIT
    --         )
    --         port map(
    --             A => XOR_RES,
    --             Y => EZ
    --         );
    -- end architecture;