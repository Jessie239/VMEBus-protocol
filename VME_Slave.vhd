

--====================================================================
--  File name   :   VME_Slave.vhd
--  Author      :   Myo Ko Ko
--  
--  Description :   This module serves as VME Slave
--  Toolchain   :   Quartus Prime Lite Edition 23.1.
--  Corporation :   <name of the corportaion>
--
--  Copyright ⓒ <Contents>
--
--  ________________
--  Revision History    
--  No. |   Version |   Data        |   Description
--  1.  |   0.1     |   2024.12.16  |   Initial Design Creation
--  2.  |   x.x     |   yyyy.mm.dd  |   [Descritpion of Changes.]
--
--====================================================================




library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library Project_Lib;
    use Project_Lib.VME_Package.all;
--____________________________________________________________________



entity VME_Slave is
    port(
        --_____________________________
        -- Clock and Asynchronous reset
        clk_16mhz       :   in std_logic;
        aReset          :   in std_logic;



        --__________________
        -- On-board switches 
        SA              :   in Switch_address;
        SAM             :   in std_logic_vector(width_2bit - 1 downto 0);
        NRP             :   in std_logic;



        --___________________
        -- VME Side interface
        LVM_AS_L        :   in std_logic;
        LVM_DS0_L, LVM_DS1_L       :   in std_logic;
        LVM_WRITE_L     :   in std_logic;
        LVM_LWORD_L     :   in std_logic;

        LVM_A           :   in VME_address;
        LVM_AM          :   in VME_address_modifier;
        LVM_D           :   inout Word;

        LVM_DDIR        :   out std_logic;
        LVM_DG_L        :   out std_logic;
        LVM_DTACK_L     :   out std_logic;



        --___________________________
        -- Internal interface signals
        VMEAddress      :   out Byte;
        VMEData_IN      :   in Word;
        VMEData_OUT     :   out Word;
        VMEWrite        :   out std_logic;
        VMERead         :   out std_logic
    );
end entity VME_Slave;
--____________________________________________________________________




architecture RTL of VME_Slave is

    signal BaseAddress          :   Switch_address;
    signal BaseAddress_Modifier :   std_logic_vector(width_5bit-1 downto 0);
    signal VMEAddress_Modifier  :   Address_Modifier_comparison;

    signal Sync_1, Sync_2       :   Synchronization;

    signal VMEData_BUF          :   Word;
    signal VMEData_BUF_OE       :   std_logic;

    signal current_state, next_state    :   VMEBus_protocol;


begin

    --______________________
    -- Register modification
    BaseAddress             <=  not SA;
    BaseAddress_Modifier    <=  '1' & '1' & not SAM & '0';  -- | 1 | 1 | not SAM(1) | not SAM(0) | 0 |
    VMEAddress_Modifier     <=  Sync_2.LVM_AM(5 downto 3) & Sync_2.LVM_AM(1 downto 0);


    --____________________
    -- 2-time optimization
    stage_latch : process(clk_16mhz, aReset)
    begin
        if aReset = '0' then
            Sync_1.LVM_AS_L     <=  '1';
            Sync_2.LVM_AS_L     <=  '1';

            Sync_1.LVM_DS0_L    <=  '1';
            Sync_2.LVM_DS1_L    <=  '1';

            Sync_1.LVM_DS1_L    <=  '1';
            Sync_2.LVM_DS1_L    <=  '1';

            Sync_1.LVM_WRITE_L  <=  '1';
            Sync_2.LVM_WRITE_L  <=  '1';

            Sync_1.LVM_LWORD_L  <=  '1';
            Sync_2.LVM_LWORD_L  <=  '1';

            Sync_1.LVM_A        <=  (Others => '0');
            Sync_2.LVM_A        <=  (Others => '0');

            Sync_1.LVM_AM       <=  (Others => '0');
            Sync_2.LVM_AM       <=  (Others => '0');

            Sync_1.LVM_D        <=  (Others => '0');
            Sync_2.LVM_D        <=  (Others => '0');
        elsif rising_edge(clk_16mhz) then
            Sync_1.LVM_AS_L     <=  LVM_AS_L;
            Sync_2.LVM_AS_L     <=  Sync_1.LVM_AS_L;

            Sync_1.LVM_DS0_L    <=  LVM_DS0_L;
            Sync_2.LVM_DS0_L    <=  Sync_1.LVM_DS0_L;

            Sync_1.LVM_DS1_L    <=  LVM_DS1_L;
            Sync_2.LVM_DS1_L    <=  Sync_1.LVM_DS1_L;

            Sync_1.LVM_WRITE_L  <=  LVM_WRITE_L;
            Sync_2.LVM_WRITE_L  <=  Sync_1.LVM_WRITE_L;

            Sync_1.LVM_LWORD_L  <=  LVM_LWORD_L;
            Sync_2.LVM_LWORD_L  <=  Sync_1.LVM_LWORD_L;

            Sync_1.LVM_A        <=  LVM_A;
            Sync_2.LVM_A        <=  Sync_1.LVM_A;

            Sync_1.LVM_AM       <=  LVM_AM;
            Sync_2.LVM_AM       <=  Sync_1.LVM_AM;

            Sync_1.LVM_D        <=  LVM_D;
            Sync_2.LVM_D        <=  Sync_1.LVM_D;
        end if;
    end process; 


    --_________________________
    -- Bidirectional Controller
    LVM_D   <=  VMEData_BUF     when VMEData_BUF_OE = '1' else (Others => 'Z');



    --___________
    -- Transition
    State_Definiation : process(clk_16mhz, aReset)
    begin
        if aReset = '0' then
            current_state   <=  IDLE;
        elsif rising_edge(clk_16mhz) then
            current_state   <=  next_state;
        end if;
    end process;


    state_transition : process(all)
    begin
        next_state  <=  current_state;

        case current_state is

        when IDLE               =>
            if is_NOReply(Sync_2.LVM_DS0_L, Sync_2.LVM_DS1_L, Sync_2.LVM_LWORD_L, NRP) then
                next_state  <=  NOReply;
            elsif Sync_2.LVM_AS_L = '0' then
                next_state  <= Address_Decode;
            end if;


        when Address_Decode     =>  
            if is_Address_Matched(Sync_2.LVM_A(23 downto 8), BaseAddress, VMEAddress_Modifier, BaseAddress_Modifier) then
                if is_vWRITE(Sync_2.LVM_DS0_L, Sync_2.LVM_DS1_L, Sync_2.LVM_WRITE_L) then
                    next_state  <=  WRITE_Cycle;
                elsif is_vREAD(Sync_2.LVM_DS0_L, Sync_2.LVM_DS1_L, Sync_2.LVM_WRITE_L) then
                    next_state  <=  READ_Cycle;
                end if;
            else
                next_state  <=  IDLE;
            end if;


        when NOReply            =>
            if is_NOReply(Sync_2.LVM_DS0_L, Sync_2.LVM_DS1_L, Sync_2.LVM_LWORD_L, NRP) then
                next_state  <=  NOReply;
            else
                next_state  <=  IDLE;
            end if;    


        when WRITE_Cycle        =>
            next_state  <=  WRITE_Cycle_1;

        when WRITE_Cycle_1      =>
            next_state  <=  WRITE_Dtack_Assert;

        when WRITE_Dtack_Assert =>
            if Sync_2.LVM_AS_L = '1' then
                next_state  <=  IDLE;
            else
                next_state  <=  WRITE_Dtack_Assert;
            end if;

        when READ_Cycle         =>
            next_state  <=  READ_Cycle_1;

        when READ_Cycle_1       =>
            next_state  <=  READ_Dtack_Assert;

        when READ_Dtack_Assert  =>
            if Sync_2.LVM_AS_L = '1' then
                next_state  <=  IDLE;
            else
                next_state  <=  READ_Dtack_Assert;
            end if;

        when Others =>
            next_state  <=  IDLE;
        end case;
    end process;


    output_logic : process(all)
    begin

        VMEData_BUF         <=  (Others => '0');
        VMEData_BUF_OE      <=  '0';    -- Set '1' to open buffer gate

        LVM_DDIR            <=  '0';    -- 0: FPGA to VME (READ)    |   1: VME to FPGA (WRITE)
        LVM_DG_L            <=  '1';    -- 0: Open the gate         |   1: Isolation
        LVM_DTACK_L         <=  '1';    -- 0: Respond               |   1: Not Respond

        VMEAddress          <=  (Others => '0');    
        VMEData_OUT         <=  (Others => '0');
        VMEWrite            <=  '0';
        VMERead             <=  '0';

        case current_state is

        when IDLE               =>
            Null;
        when NOReply            =>
            Null;
        when Address_Decode     =>
            Null;

        when WRITE_Cycle        =>
            LVM_DDIR    <=  '1';
            LVM_DG_L    <=  '0';
            VMEAddress  <=  Sync_2.LVM_A(8 downto 1);
            VMEData_OUT <=  Sync_2.LVM_D;
            VMEWrite    <=  '1';

        when WRITE_Cycle_1      =>
            LVM_DDIR    <=  '1';
            LVM_DG_L    <=  '0';
            VMEAddress  <=  Sync_2.LVM_A(8 downto 1);
            VMEData_OUT <=  Sync_2.LVM_D;
            VMEWrite    <=  '1';

        when WRITE_Dtack_Assert =>
            LVM_DDIR    <=  '1';
            LVM_DG_L    <=  '0';
            LVM_DTACK_L <=  '0';
            VMEAddress  <=  Sync_2.LVM_A(8 downto 1);
            VMEData_OUT <=  Sync_2.LVM_D;
            VMEWrite    <=  '1';

        when READ_Cycle         =>
            VMEData_BUF     <=  VMEData_IN;
            VMEData_BUF_OE  <=  '1';
            LVM_DDIR        <=  '0';
            LVM_DG_L        <=  '0';
            VMEAddress      <=  Sync_2.LVM_A(8 downto 1);
            VMERead         <=  '1';

        when READ_Cycle_1       =>
            VMEData_BUF     <=  VMEData_IN;
            VMEData_BUF_OE  <=  '1';
            LVM_DDIR        <=  '0';
            LVM_DG_L        <=  '0';
            VMEAddress      <=  Sync_2.LVM_A(8 downto 1);
            VMERead         <=  '1';

        when READ_Dtack_Assert  =>
            VMEData_BUF     <=  VMEData_IN;
            VMEData_BUF_OE  <=  '1';
            LVM_DDIR        <=  '0';
            LVM_DG_L        <=  '0';
            LVM_DTACK_L     <=  '0';
            VMEAddress      <=  Sync_2.LVM_A(8 downto 1);
            VMERead         <=  '1';

        when Others =>
            Null;      
        end case;  
    end process;


end architecture RTL;

