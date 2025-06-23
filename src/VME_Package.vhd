

--====================================================================
--  File name   :   VME_Package.vhd
--  Author      :   Myo Ko Ko
--  
--  Description :   This package contatins -
--  1) constants
--  2) subtypes
--  3) functions
--  5) record
--  6) enumerated type
--  
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
--____________________________________________________________________




package VME_Package is

-- CONSTANTS
    constant width_2bit     :   integer := 2;
    constant width_4bit     :   integer := 4;
    constant width_5bit     :   integer := 5;
    constant width_6bit     :   integer := 6;
    constant width_8bit     :   integer := 8;
    constant width_16bit    :   integer := 16;
    constant width_24bit    :   integer := 24;



-- SUBTYPES
    subtype Nibble is std_logic_vector(width_4bit - 1 downto 0);
    subtype Byte is std_logic_vector(width_8bit - 1 downto 0);
    subtype Word is std_logic_vector(width_16bit - 1 downto 0);
    subtype VME_address is std_logic_vector(width_24bit - 1 downto 1);
    subtype VME_address_modifier is std_logic_vector(width_6bit - 1 downto 0);
    subtype Switch_address is std_logic_vector(width_24bit - 1 downto 8);

    subtype Address_Modifier_comparison is std_logic_vector(width_5bit-1 downto 0);



-- FUNCTIONS    
    function is_NOReply(
        ds0, ds1, long_word, sw_noreply   :   std_logic
    ) return boolean;

    function is_Address_Matched(
        VMEAddress              :   Switch_address;
        BoardAddress            :   Switch_address;        
        VMEAddress_Modifier     :   Address_Modifier_comparison;
        BoardAddress_Modifier   :   Address_Modifier_comparison
    ) return boolean;

    function is_vWRITE(
        DS0, DS1, WR    :   std_logic
    ) return boolean;

    function is_vREAD(
        DS0, DS1, RD    :   std_logic
    ) return boolean;



-- TYPE RECORD
    type Synchronization is record
        LVM_AS_L        :   std_logic;
        LVM_DS0_L, LVM_DS1_L    :   std_logic;
        LVM_WRITE_L     :   std_logic;
        LVM_LWORD_L     :   std_logic;  
        LVM_A           :   VME_address;
        LVM_AM          :   VME_address_modifier;
        LVM_D           :   Word;
    end record;




-- State TYPES
    type VMEBus_protocol is(
        IDLE,
        NOReply,
        Address_Decode,

        WRITE_Cycle,
        WRITE_Cycle_1,
        WRITE_Dtack_Assert,

        READ_Cycle,
        READ_Cycle_1,
        READ_Dtack_Assert
    );


end package VME_Package;
--____________________________________________________________________




package body VME_Package is

    function is_NOReply(
        ds0, ds1, long_word, sw_noreply   :   std_logic
    ) return boolean is
    begin
        return (ds0 = '0' and ds1 = '0' and long_word = '0') or (sw_noreply = '0');
    end function is_NOReply;    

    function is_Address_Matched(
        VMEAddress              :   Switch_address;
        BoardAddress            :   Switch_address;
        VMEAddress_Modifier     :   Address_Modifier_comparison;
        BoardAddress_Modifier   :   Address_Modifier_comparison
    ) return boolean is 
    begin
        return (VMEAddress = BoardAddress) and (VMEAddress_Modifier = BoardAddress_Modifier);
    end function is_Address_Matched;

    function is_vWRITE(
        DS0, DS1, WR    :   std_logic
    ) return boolean is
    begin
        return DS0 = '0' and DS1 = '0' and WR = '0';
    end function is_vWRITE;

    function is_vREAD(
        DS0, DS1, RD    :   std_logic
    ) return boolean is
    begin
        return DS0 = '0' and DS1 = '0' and RD = '1';
    end function is_vREAD;


end package body;

