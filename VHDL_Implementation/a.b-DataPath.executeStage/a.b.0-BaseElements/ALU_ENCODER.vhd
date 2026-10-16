library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
use ieee.std_logic_arith.all;
use work.myTypes.all;

entity ALU_ENCODER is
    port(
        CMD : in aluOp;
        MUX_OUT_SEL : out std_logic_vector(1 downto 0);         -- selection signal for the MUX which chooses the output of the correct unit
        MULT_EN : out std_logic;                                -- Enables the Pipe registers of the Multiplier
        ADD_CIN : out std_logic;                                -- Carry in of the add/sub (ADD_CIN = '0' --> ADD , ADD_CIN = '1' --> SUB)
        LOGIC_SEL : out std_logic_vector (3 downto 0);          -- Selects the correct logical operation
        COMP_SEL :  out std_logic_vector (2 downto 0);          -- Selection signal for the comparator
        COMP_TYPE : out std_logic;                              -- Signed( = '1') or unsigned ( = '0' )comparison --> it changes only for lower (<) comparison 
        SHIFT_CONFIG : out std_logic_vector (1 downto 0)        -- selects direction and type of the shift
    );
end entity;


architecture BHV of ALU_ENCODER is

begin

    process(CMD)
    begin

        -- Default values
        MUX_OUT_SEL <= "00";
        MULT_EN <= '0';
        ADD_CIN <= '0';
        LOGIC_SEL <= "0000";
        COMP_SEL <= "000";
        COMP_TYPE <= '0';
        SHIFT_CONFIG <= "00";

        case CMD is

            when NOP =>
                null;

            when ADD =>
                MUX_OUT_SEL <= "00";

            when SUB =>
                MUX_OUT_SEL <= "00";
                ADD_CIN <= '1';

            when EQ =>
                MUX_OUT_SEL <= "10";
                COMP_SEL <= "000";

            when NE =>
                MUX_OUT_SEL <= "10";
                COMP_SEL <= "101";

            when GT =>
                MUX_OUT_SEL <= "10";
                COMP_SEL <= "011";

            when GE =>
                MUX_OUT_SEL <= "10";
                COMP_SEL <= "100";

            when LT =>
                MUX_OUT_SEL <= "10";
                COMP_SEL <= "001";
                COMP_TYPE <= '1';

            when LT_U =>
                MUX_OUT_SEL <= "10";
                COMP_SEL <= "001";
        

            when LE =>
                MUX_OUT_SEL <= "10";
                COMP_SEL <= "010";

            when AND_OP =>
                MUX_OUT_SEL <= "01";
                LOGIC_SEL <= "1000";

            when NAND_OP =>
                MUX_OUT_SEL <= "01";
                LOGIC_SEL <= "0111";

            when OR_OP =>
                MUX_OUT_SEL <= "01";
                LOGIC_SEL <= "1110";

            when NOR_OP =>
                MUX_OUT_SEL <= "01";
                LOGIC_SEL <= "0001";

            when XOR_OP =>
                MUX_OUT_SEL <= "01";
                LOGIC_SEL <= "0110";

            when XNOR_OP =>
                MUX_OUT_SEL <= "01";
                LOGIC_SEL <= "1001";

            when MULT =>
                MUX_OUT_SEL <= "00";
                MULT_EN <= '1';

            when SLL_OP =>
                MUX_OUT_SEL <= "11";
                SHIFT_CONFIG <= "10";

            when SRL_OP =>
                MUX_OUT_SEL <= "11";
                SHIFT_CONFIG <= "11";

            when SRA_OP =>
                MUX_OUT_SEL <= "11";
                SHIFT_CONFIG <= "01";

            when others =>
                null;

        end case;

    end process;

end architecture BHV;
