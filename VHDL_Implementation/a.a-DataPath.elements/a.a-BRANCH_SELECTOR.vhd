library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.myTypes.all;

entity BRANCH_SELECTOR is

    -- Used in the execute stage to select how the next program counter should be updated
    -- The modes are defined in the 000-globals file.
    -- Works asynchronously based on BRANCH_MODE and EQ_ZERO_RSLT

    generic (
        NBIT : natural := 32
    );
    port (
        BRANCH_MODE : in branchSelection_t; -- Input to select the branch condition 
        EQ_ZERO_RSLT : in std_logic; -- Input from the zero comparator to use for conditional branches (if this signal is high the input is assumed to be 0)

        BRANCH_SEL : out std_logic -- Output to be sent to the branch selection MUX. It will be 0 for taking the NPC form the decode stage or 1 for taking the NPC from the ALU result
    );

end BRANCH_SELECTOR;

architecture BEHAVIORAL of BRANCH_SELECTOR is

begin

    -- Async process used to deter
    process (BRANCH_MODE, EQ_ZERO_RSLT) is
    begin
        case BRANCH_MODE is
            when NO_BRANCH =>
                BRANCH_SEL <= '0';
            when BRANCH_EQZ =>
                BRANCH_SEL <= EQ_ZERO_RSLT;
            when BRANCH_NEQZ =>
                BRANCH_SEL <= not EQ_ZERO_RSLT;
            when BRANCH_ALL =>
                BRANCH_SEL <= '1';
            when others =>
                null;
        end case;
        
    end process;

end architecture;