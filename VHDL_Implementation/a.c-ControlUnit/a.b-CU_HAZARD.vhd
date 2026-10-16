
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.myTypes.all;
use work.cpu_32b_types.all;

-- hazard unit + forwarding logic
-- The RS2 is always forwarded, worst case if it is not needed the enable signal will be low and it will retain its current value

entity CU_HAZARD is
    generic (
        NBIT : natural := 32; -- Data width, for forwarded values
        NBIT_IDX : natural := 5 -- bits of the register address 
    );
    port (
        CLK : in std_logic;
        NRST : in std_logic;

        
        IS_RR_OP : in std_logic;-- Indicates if the current (instruction in the decode stage) is a register-register operation
        IS_STORE : in std_logic;-- Indicates if the current (instruction in the decode stage) is a store operation

        -- Register addresses from different pipeline stages 
        RD_ADDR_FET : in std_logic_vector (NBIT_IDX - 1 downto 0); -- Register address from fetch stage
        RD_ADDR_DEC : in std_logic_vector (NBIT_IDX - 1 downto 0); -- Register address from decode stage
        RD_ADDR_EX : in std_logic_vector (NBIT_IDX - 1 downto 0); -- RD address from execute stage 
        RD_ADDR_MEM : in std_logic_vector (NBIT_IDX - 1 downto 0); -- RD address from memory
        RD_ADDR_WB : in std_logic_vector (NBIT_IDX - 1 downto 0); -- RD address from writeback

        RS1_ADDR_IF, RS2_ADDR_IF : in std_logic_vector (NBIT_IDX - 1 downto 0); -- The RS1, RS2 addresses of the instruction that is currently being decoded (from the output of IR_IN of the fetch stage, combinationally so no clk cycles of delay)

        -- Register write enables per pipeline stage
        RD_WEN_DEC : in std_logic; -- RegWrite of the decode stage 
        RD_WEN_EX : in std_logic; -- RegWrite of the instruction currently in EX stage
        RD_WEN_MEM : in std_logic; -- RegWrite of the instruction currently in MEM stage
        RD_WEN_WB : in std_logic; -- RegWrite of the instruction currently in WB stage

        -- Load instruction indicator for hazard detection
        IS_LOAD_EX : in std_logic; -- Marks the instruction in EX as a load (LW class): its result is only
        IS_LOAD_MEM : in std_logic; -- Marks the instruction in MEM as a load
        -- ready at the end of MEM, so forwarding cannot resolve this distance

        -- Register windowing stall sources (from register_file_windowed)
        SPILL : in std_logic;
        FILL : in std_logic;

        -- Memory request signals for structural hazard detection: if any of these signals goes high while a stall caused by the register file SPILL/FILL then there is a structural hazard?
        MEM_RD_REQUEST : in std_logic; -- Memory read request
        MEM_WR_REQUEST : in std_logic; -- Memory Write request 

        -- Branch prediction and flush signals
        MISPREDICT_FLUSH : in std_logic; -- branch misprediction flush, one cycle after UPDATE_EN (see BRANCH_PREDICTOR.FLUSH)

        -- Forwarding data from pipeline stages
        ALU_OUT_RESULT : in std_logic_vector(NBIT - 1 downto 0); -- result coming directly from the ALU of the execute stage, combinatorially (this way an extra clock cycle can be saved by avoiding the ALU_OUT pipeline register)
        EX_MEM_RESULT : in std_logic_vector (NBIT - 1 downto 0); -- result held in the EX -> MEM pipeline register
        MEM_WB_RESULT : in std_logic_vector (NBIT - 1 downto 0); -- result held in the MEM -> WB pipeline register
        WB_RESULT : in std_logic_vector (NBIT - 1 downto 0); -- result held in the WB pipeline register

        -- Forwarded data out
        RS1_FWD_DATA, RS2_FWD_DATA : out std_logic_vector(NBIT - 1 downto 0); -- data that will be loaded to the RS1/RS2 registers if the respective FWD_EN flag is set
        RS1_FWD_EN, RS2_FWD_EN : out std_logic;

        -- Pipeline stage enable signals
        EN_IF, EN_ID, EN_EXE, EN_MEM, EN_WB : out std_logic; -- Enable signals for each pipeline stage
        STALL : out std_logic; -- Used to inject NOPs in the exec stage (this is done in the datapath entity)
        FLUSH_IF_ID : out std_logic;
        FLUSH_ID_EX : out std_logic
    );

end CU_HAZARD;

architecture RTL of CU_HAZARD is
    -- signal fet_hazard, dec_hazard, exe_hazard, mem_hazard, wb_hazard : std_logic;
    signal exe_hazard, mem_hazard : std_logic;
    signal RS1_ADDR_ID, RS2_ADDR_ID : std_logic_vector (NBIT_IDX - 1 downto 0);

    signal load_use_hazard, window_stall, mem_struct_hazard : std_logic;

    type FWD_SEL_TYPE is (NO_FWD, FWD_ALU, FWD_EXE, FWD_MEM, FWD_WB); -- In FWD_STAGE, the STAGE stands for the stage which contains the filled pipeline register at present. For the ALU option, this is to take the value from the ALU output directly
    signal sel_in1, sel_in2 : FWD_SEL_TYPE;
    signal uses_rs2 : std_logic;
begin

    DELAY_RS_ADDR : process (CLK) begin
        if rising_edge(CLK) then
            RS1_ADDR_ID <= RS1_ADDR_IF;
            RS2_ADDR_ID <= RS2_ADDR_IF;
        end if;
    end process;

    -- fet_hazard <= '1' when RD_ADDR_FET /= 0 and ((RD_ADDR_FET = RS1_ADDR_IF) or ((IS_RR_OP = '1') and (RD_ADDR_FET = RS2_ADDR_IF))) else
    --     '0';

    -- dec_hazard <= '1' when RD_ADDR_DEC /= 0 and ((RD_ADDR_DEC = RS1_ADDR_ID) or ((IS_RR_OP = '1') and (RD_ADDR_DEC = RS2_ADDR_ID))) else
    --     '0';
    uses_rs2 <= IS_RR_OP or IS_STORE;
    -- Check at the EXE stage: load-use hazard, cannot be solved by forwarding
    exe_hazard <= '1' when RD_ADDR_DEC /= 0 and RD_WEN_DEC = '1' and IS_LOAD_EX = '1' and
        ((RD_ADDR_DEC = RS1_ADDR_IF) or ((uses_rs2 = '1') and (RD_ADDR_DEC = RS2_ADDR_IF))) else
        '0'; -- ToDo: Probably the second part of the expression evaluating RS2 needs to be modified. A load will use only RS1 to compute the address (and RS1 can use forwarding)

    -- -- Check at the MEM stage: load-use hazard, cannot be solved by forwarding
    mem_hazard <= '0' when RD_ADDR_EX /= 0 and RD_WEN_EX = '1' and IS_LOAD_MEM = '1' and
        ((RD_ADDR_EX = RS1_ADDR_ID) or ((uses_rs2 = '1') and (RD_ADDR_EX = RS2_ADDR_IF))) else
        '0'; -- ToDo: Probably the second part of the expression evaluating RS2 needs to be modified. A load will use only RS1 to compute the address (and RS1 can use forwarding)

    -- -- Check at the WB stage: solved by forwarding from MEM/WB
    -- wb_hazard <= '1' when RD_ADDR_WB /= 0 and RD_WEN_WB = '1' and
    --     ((RD_ADDR_WB = RS1_ADDR_ID) or ((IS_RR_OP = '1') and (RD_ADDR_WB = RS2_ADDR_ID))) else
    --     '0';

    load_use_hazard <= exe_hazard or mem_hazard;

    window_stall <= SPILL or FILL; -- Stall commanded from the register file entering the SPILL/FILL state (requires memory access, and will generate invalid register data during the process)

    mem_struct_hazard <= '0';--(MEM_RD_REQUEST or MEM_WR_REQUEST) ;

    -- Forwarding selection: EX/MEM (closer, more recent) has priority over MEM/WB
    sel_in1 <=
        -- FWD_ALU when RD_ADDR_DEC /= 0 and RD_WEN_DEC = '1' and RD_ADDR_DEC = RS1_ADDR_IF else
        FWD_EXE when RD_ADDR_EX /= 0 and RD_WEN_EX = '1' and RD_ADDR_EX = RS1_ADDR_ID and IS_LOAD_EX = '0' else
        FWD_MEM when RD_ADDR_MEM /= 0 and RD_WEN_MEM = '1' and RD_ADDR_MEM = RS1_ADDR_ID else
        FWD_WB when RD_ADDR_WB /= 0 and RD_WEN_WB = '1' and RD_ADDR_WB = RS1_ADDR_ID else
        NO_FWD;

    sel_in2 <=
        -- FWD_ALU when RD_ADDR_DEC /= 0 and RD_WEN_DEC = '1' and RD_ADDR_DEC = RS2_ADDR_IF else
        FWD_EXE when RD_ADDR_EX /= 0 and RD_WEN_EX = '1' and RD_ADDR_EX = RS2_ADDR_ID else
        FWD_MEM when RD_ADDR_MEM /= 0 and RD_WEN_MEM = '1' and RD_ADDR_MEM = RS2_ADDR_ID else
        FWD_WB when RD_ADDR_WB /= 0 and RD_WEN_WB = '1' and RD_ADDR_WB = RS2_ADDR_ID else
        NO_FWD;

    -- Select the actual data to be sent out
    RS1_FWD_DATA <=
        ALU_OUT_RESULT when sel_in1 = FWD_ALU else
        EX_MEM_RESULT when sel_in1 = FWD_EXE else
        MEM_WB_RESULT when sel_in1 = FWD_MEM else
        WB_RESULT when sel_in1 = FWD_WB else
        (others => '0');

    RS2_FWD_DATA <=
        ALU_OUT_RESULT when sel_in2 = FWD_ALU else
        EX_MEM_RESULT when sel_in2 = FWD_EXE else
        MEM_WB_RESULT when sel_in2 = FWD_MEM else
        WB_RESULT when sel_in2 = FWD_WB else
        (others => '0');

    -- Propagate forwarding enable signals
    RS1_FWD_EN <= '0' when sel_in1 = NO_FWD else
        '1';
    RS2_FWD_EN <= '0' when sel_in2 = NO_FWD else
        '1';

    EN_IF <= (not (load_use_hazard or window_stall or mem_struct_hazard)) or (not NRST);
    EN_ID <= (not (load_use_hazard or window_stall or mem_struct_hazard)) or (not NRST);
    EN_EXE <= (not (window_stall or mem_struct_hazard)) or (not NRST);
    EN_MEM <= (not (window_stall or mem_struct_hazard)) or (not NRST);
    EN_WB <= '1';

    STALL <= load_use_hazard or window_stall or mem_struct_hazard;

    FLUSH_IF_ID <= not (load_use_hazard or window_stall or mem_struct_hazard);
    -- FLUSH_IF_ID <= MISPREDICT_FLUSH;
    FLUSH_ID_EX <= MISPREDICT_FLUSH;

end architecture;