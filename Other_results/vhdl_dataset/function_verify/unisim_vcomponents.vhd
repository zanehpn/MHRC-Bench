-- Shared UNISIM VComponents package
-- Contains component declarations for: ODDR, OSERDESE2, PLLE2_ADV, BUFG, OBUFDS

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package VComponents is

    component ODDR
        generic (
            DDR_CLK_EDGE : string := "SAME_EDGE";
            INIT         : bit    := '0';
            SRTYPE       : string := "SYNC"
        );
        port (
            Q  : out std_logic;
            C  : in  std_logic;
            CE : in  std_logic;
            R  : in  std_logic;
            S  : in  std_logic;
            D1 : in  std_logic;
            D2 : in  std_logic
        );
    end component;

    component OSERDESE1
        generic (
            DATA_RATE_OQ   : string  := "DDR";
            DATA_RATE_TQ   : string  := "DDR";
            DATA_WIDTH     : integer := 4;
            INIT_OQ        : bit     := '0';
            INIT_TQ        : bit     := '0';
            SERDES_MODE    : string  := "MASTER";
            SRVAL_OQ       : bit     := '0';
            SRVAL_TQ       : bit     := '0';
            TRISTATE_WIDTH : integer := 4;
            INTERFACE_TYPE : string  := "DEFAULT"
        );
        port (
            OFB          : out std_logic;
            OQ           : out std_logic;
            SHIFTOUT1    : out std_logic;
            SHIFTOUT2    : out std_logic;
            TFB          : out std_logic;
            TQ           : out std_logic;
            CLK          : in  std_logic;
            CLKDIV       : in  std_logic;
            CLKPERF      : in  std_logic;
            CLKPERFDELAY : in  std_logic;
            D1           : in  std_logic;
            D2           : in  std_logic;
            D3           : in  std_logic;
            D4           : in  std_logic;
            D5           : in  std_logic;
            D6           : in  std_logic;
            OCE          : in  std_logic;
            ODV          : in  std_logic;
            RST          : in  std_logic;
            SHIFTIN1     : in  std_logic;
            SHIFTIN2     : in  std_logic;
            T1           : in  std_logic;
            T2           : in  std_logic;
            T3           : in  std_logic;
            T4           : in  std_logic;
            TCE          : in  std_logic;
            WC           : in  std_logic
        );
    end component;

    component OSERDESE2
        generic (
            DATA_RATE_OQ   : string  := "DDR";
            DATA_RATE_TQ   : string  := "DDR";
            DATA_WIDTH     : integer := 4;
            INIT_OQ        : bit     := '0';
            INIT_TQ        : bit     := '0';
            SERDES_MODE    : string  := "MASTER";
            SRVAL_OQ       : bit     := '0';
            SRVAL_TQ       : bit     := '0';
            TBYTE_CTL      : string  := "FALSE";
            TBYTE_SRC      : string  := "FALSE";
            TRISTATE_WIDTH : integer := 4
        );
        port (
            OFB       : out std_logic;
            OQ        : out std_logic;
            SHIFTOUT1 : out std_logic;
            SHIFTOUT2 : out std_logic;
            TBYTEOUT  : out std_logic;
            TFB       : out std_logic;
            TQ        : out std_logic;
            CLK       : in  std_logic;
            CLKDIV    : in  std_logic;
            D1        : in  std_logic;
            D2        : in  std_logic;
            D3        : in  std_logic;
            D4        : in  std_logic;
            D5        : in  std_logic;
            D6        : in  std_logic;
            D7        : in  std_logic;
            D8        : in  std_logic;
            OCE       : in  std_logic;
            RST       : in  std_logic;
            SHIFTIN1  : in  std_logic;
            SHIFTIN2  : in  std_logic;
            T1        : in  std_logic;
            T2        : in  std_logic;
            T3        : in  std_logic;
            T4        : in  std_logic;
            TBYTEIN   : in  std_logic;
            TCE       : in  std_logic
        );
    end component;

    component PLLE2_ADV
        generic (
            BANDWIDTH          : string  := "OPTIMIZED";
            CLKIN1_PERIOD      : real    := 0.000;
            CLKIN2_PERIOD      : real    := 0.000;
            CLKOUT0_DIVIDE     : integer := 1;
            CLKOUT1_DIVIDE     : integer := 1;
            CLKOUT2_DIVIDE     : integer := 1;
            CLKOUT3_DIVIDE     : integer := 1;
            CLKOUT4_DIVIDE     : integer := 1;
            CLKOUT5_DIVIDE     : integer := 1;
            CLKOUT0_PHASE      : real    := 0.0;
            CLKOUT1_PHASE      : real    := 0.0;
            CLKOUT2_PHASE      : real    := 0.0;
            CLKOUT3_PHASE      : real    := 0.0;
            CLKOUT4_PHASE      : real    := 0.0;
            CLKOUT5_PHASE      : real    := 0.0;
            CLKOUT0_DUTY_CYCLE : real    := 0.5;
            CLKOUT1_DUTY_CYCLE : real    := 0.5;
            CLKOUT2_DUTY_CYCLE : real    := 0.5;
            CLKOUT3_DUTY_CYCLE : real    := 0.5;
            CLKOUT4_DUTY_CYCLE : real    := 0.5;
            CLKOUT5_DUTY_CYCLE : real    := 0.5;
            COMPENSATION       : string  := "ZHOLD";
            DIVCLK_DIVIDE      : integer := 1;
            CLKFBOUT_MULT      : integer := 2;
            CLKFBOUT_PHASE     : real    := 0.0;
            REF_JITTER1        : real    := 0.100;
            STARTUP_WAIT       : string  := "FALSE"
        );
        port (
            CLKIN1   : in  std_logic;
            CLKIN2   : in  std_logic;
            CLKFBIN  : in  std_logic;
            CLKINSEL : in  std_logic;
            RST      : in  std_logic;
            PWRDWN   : in  std_logic;
            DADDR    : in  std_logic_vector(6 downto 0);
            DI       : in  std_logic_vector(15 downto 0);
            DWE      : in  std_logic;
            DEN      : in  std_logic;
            DCLK     : in  std_logic;
            DRDY     : out std_logic;
            DO       : out std_logic_vector(15 downto 0);
            CLKOUT0  : out std_logic;
            CLKOUT1  : out std_logic;
            CLKOUT2  : out std_logic;
            CLKOUT3  : out std_logic;
            CLKOUT4  : out std_logic;
            CLKOUT5  : out std_logic;
            CLKFBOUT : out std_logic;
            LOCKED   : out std_logic
        );
    end component;

    component BUFG
        port (
            O : out std_ulogic;
            I : in  std_ulogic
        );
    end component;

    component OBUFDS is
        generic (
            IOSTANDARD : string := "DEFAULT"
        );
        port (
            I  : in  std_logic;
            O  : out std_logic;
            OB : out std_logic
        );
    end component;

    component LUT6
        generic (
            INIT : bit_vector(63 downto 0) := X"0000000000000000"
        );
        port (
            O  : out std_logic;
            I0 : in  std_logic;
            I1 : in  std_logic;
            I2 : in  std_logic;
            I3 : in  std_logic;
            I4 : in  std_logic;
            I5 : in  std_logic
        );
    end component;

    component CARRY4
        port (
            CO     : out std_logic_vector(3 downto 0);
            O      : out std_logic_vector(3 downto 0);
            CI     : in  std_logic;
            CYINIT : in  std_logic;
            DI     : in  std_logic_vector(3 downto 0);
            S      : in  std_logic_vector(3 downto 0)
        );
    end component;

end package VComponents;
