library IEEE;

use IEEE.std_logic_1164.all;
use WORK.all;

entity tb_eq_zero is
end tb_eq_zero;

architecture TEST_BEHAVIORAL of tb_eq_zero is

    component EQ_ZERO generic (
        NBIT : natural := 32
        );
        port (
            D : in std_logic_vector (NBIT - 1 downto 0); -- Input data
            EZ : out std_logic -- Will be '1' if D is 0 or '0' if it is not (Equal Zero)
        );
    end component;

    component EQ_ZERO_BEHAVIORAL generic (
        NBIT : natural := 32
        );
        port (
            D : in std_logic_vector (NBIT - 1 downto 0); -- Input data
            EZ : out std_logic -- Will be '1' if D is 0 or '0' if it is not (Equal Zero)
        );
    end component;

    signal data : std_logic_vector(31 downto 0);
    signal zero : std_logic;
    signal zero_beh : std_logic;
begin

    EQ_Z : EQ_ZERO
    port map(
        D => data,
        EZ => zero
    );

    EQ_Z_CHECK : EQ_ZERO_BEHAVIORAL
    port map(
        D => data,
        EZ => zero_beh
    );

    CHECK_RESULTS : process (zero, zero_beh)
    begin
        if zero /= zero_beh then
            assert false
            report "EQ_ZERO output differs from EQ_ZERO_BEHAVIORAL output"
                severity error;
        end if;
    end process CHECK_RESULTS;

    TEST_PROC : process
    begin
        data <= x"00000000";
        wait for 10 ns;

        data <= x"00000001";
        wait for 10 ns;

        data <= x"FFFFFFFF";
        wait for 10 ns;

        data <= x"80000000";
        wait for 10 ns;

        data <= x"7FFFFFFF";
        wait for 10 ns;

        data <= x"0000FFFF";
        wait for 10 ns;

        wait;

    end process;

end TEST_BEHAVIORAL;