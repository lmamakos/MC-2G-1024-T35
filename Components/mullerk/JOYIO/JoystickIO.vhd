-- Read-Out of Piano-Switch,
--             Push-Buttons and
--             Fire-Buttons and
--             count values of pwm-measurement
--             Uptime-Counter and
--             Pseudo-RND-Generator

library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use ieee.std_logic_unsigned.all;

entity joystickIO is
   port (
      clk      : in  std_logic;                    -- joystick-clock
      Clk1ms   : in  std_logic;                    -- 1ms clock for UptimeCounter
      n_reset  : in  std_logic;
      n_RD     : in  std_logic;                    -- n_ioRD
      n_WR     : in  std_logic;                    -- n_ioWR
      n_CS     : in  std_logic;                    -- n_InterfaceJCS
      regSel   : in  std_logic_vector(3 downto 0);
      dataIn   : in  std_logic_vector(1 downto 0); -- Bit(1..0) of CPU Databus to select storage register
      dataOut  : out std_logic_vector(7 downto 0);
      compPWM  : in  std_logic_vector(3 downto 0);
      fireBTN  : in  std_logic_vector(3 downto 0);
      pushBTN  : in  std_logic_vector(3 downto 0);
      pianoSWB : in  std_logic_vector(7 downto 0)
   );
end joystickIO;

architecture rtl of joystickIO is

signal pwmCNT1    : std_logic_vector(15 downto 0);   -- x-channel joystick1 counter value
signal pwmCNT2    : std_logic_vector(15 downto 0);   -- y-channel joystick1 counter value
signal pwmCNT3    : std_logic_vector(15 downto 0);   -- x-channel joystick2 counter value
signal pwmCNT4    : std_logic_vector(15 downto 0);   -- y-channel joystick2 counter value

signal compPWM1   : std_logic;                       -- Signals from Analog_to_PWM-Converter
signal compPWM2   : std_logic;                       -- Signals from Analog_to_PWM-Converter
signal compPWM3   : std_logic;                       -- Signals from Analog_to_PWM-Converter
signal compPWM4   : std_logic;                       -- Signals from Analog_to_PWM-Converter

signal IndexReg   : std_logic_vector(1 downto 0) := (others=>'0'); -- Index-Register for Storage-Reg. Readback
signal UpTimeData : std_logic_vector(31 downto 0);                     --

signal RND16      : std_logic_vector(15 downto 0);
signal clkRND     : std_logic;
signal cntRND     : std_logic_vector(7 downto 0) := (others=>'0');

begin

-- ------------------------------------------------------------------------
--  RNDgen: generate 16-bit pseudo random numbers
-- ------------------------------------------------------------------------
    -- connect RND-Generator interface ...
    RndGen : entity work.LFSR
    PORT MAP
    (
       clk      => clkRND,
       n_RD     => n_RD,
       n_WR     => n_WR,
       n_CS     => n_CS,
       RegSEL   => RegSEL,
       Dataout  => RND16
    );

    -- generate the 500kHz clock from JOYclock for RND-Generator
    PROCESS (CLK,cntRND)
      begin
         if cntRND < 4 then              -- 5MHz / 5 = 1MHz
            cntRND <= cntRND +1;
         else
            cntRND <= (others=>'0');
            ClkRND <= NOT clkRND;        -- 1MHz / 2 = 500kHz
         end if;
      end process;

-- ------------------------------------------------------------------------
--  NEW: Convert the PWM-Signal comPWM(3)..(0) to a counter value, now in
--       separate entyties. That gives a much clearer view on what's going
--       on here
-- ------------------------------------------------------------------------

    -- do some signal re-routing, simplifies asigning the right PWM-count
    -- to the right output port ...
    compPWM1 <= comppwm(0);
    compPWM2 <= comppwm(1);
    compPWM3 <= comppwm(2);
    compPWM4 <= comppwm(3);

    -- The clock (= 5MHz) is choosen that way to produce a count value of max.
    -- ~6500 counts at full puls width. So its possible to do some averaging
    -- with 16-bit integer variables without overflow.
    pdc1: entity work.pulse_len_measure  -- pulse_len_measure
    port map (
      i_clk          => clk,              -- we use 5MHz als clock
      i_rstb         => n_RESET,          -- RESET is low active
      i_input        => compPWM1,         -- the PWM-Signal to measure low-time
      o_pulse_len_hi => OPEN,             -- HIGH-time count here not used
      o_pulse_len_lo => pwmCNT1           -- we need to know the low-count
    );

    pdc2: entity work.pulse_len_measure
    port map (
      i_clk          => clk,
      i_rstb         => n_RESET,
      i_input        => compPWM2,
      o_pulse_len_hi => OPEN,
      o_pulse_len_lo => pwmCNT2
    );

    pdc3: entity work.pulse_len_measure
    port map (
      i_clk          => clk,
      i_rstb         => n_RESET,
      i_input        => compPWM3,
      o_pulse_len_hi => OPEN,
      o_pulse_len_lo => pwmCNT3
    );

    pdc4: entity work.pulse_len_measure
    port map (
      i_clk          => clk,
      i_rstb         => n_RESET,
      i_input        => compPWM4,
      o_pulse_len_hi => OPEN,
      o_pulse_len_lo => pwmCNT4
    );

-- ---------------------------------------------------------------------
-- UpTime-Counter for Low-Puls measurement
-- ---------------------------------------------------------------------

     UPTME1: entity work.UpTime
        port map(
           Clk1ms  => Clk1ms,      -- 1ms clock for UptimeCounter
           n_reset => n_RESET,
           n_WR    => n_WR,        -- n_ioWR
           n_RD    => n_RD,        -- n_ioWR
           n_CS    => n_CS,        -- n_InterfaceJCS
           regSel  => RegSel,      -- selects a counter register
           datain  => datain,      -- data to select Time-Register
           dataOut => UpTimeData   -- feeds the counter value to the cpu
        );

-- --------------------------------------------------------------------------------------------------------------------------------
-- DataOut-Multiplexer driven by 'RegSel'
-- --------------------------------------------------------------------------------------------------------------------------------

   DataOut <=
      -- Read data from JOYIO-Hardware
      pianoSWB                   WHEN RegSel = "0000" AND n_CS = '0' AND n_RD = '0' else  -- state of piona-switch
      pushBTN & fireBTN          WHEN RegSel = "0001" AND n_CS = '0' AND n_RD = '0' else  -- state of 4 push-buttons (HIGH Nibble) &
                                                                                          --    state of 4 fire-buttons (LOW  Nibble)
      pwmCNT1(7 downto 0)        WHEN RegSel = "0010" AND n_CS = '0' AND n_RD = '0' else  -- count value of x-channel joystick1
      pwmCNT1(15 downto 8)       WHEN RegSel = "0011" AND n_CS = '0' AND n_RD = '0' else
      pwmCNT2(7 downto 0)        WHEN RegSel = "0100" AND n_CS = '0' AND n_RD = '0' else  -- count value of y-channel joystick1
      pwmCNT2(15 downto 8)       WHEN RegSel = "0101" AND n_CS = '0' AND n_RD = '0' else

      pwmCNT3(7 downto 0)        WHEN RegSel = "0110" AND n_CS = '0' AND n_RD = '0' else  -- count value of x-channel joystick2
      pwmCNT3(15 downto 8)       WHEN RegSel = "0111" AND n_CS = '0' AND n_RD = '0' else
      pwmCNT4(7 downto 0)        WHEN RegSel = "1000" AND n_CS = '0' AND n_RD = '0' else  -- count value of y-channel joystick2
      pwmCNT4(15 downto 8)       WHEN RegSel = "1001" AND n_CS = '0' AND n_RD = '0' else

      -- Reading UpTimeCounter from Uptime
      UpTimeData(7 downto 0)     when RegSel = "1010" AND n_CS = '0' AND n_RD = '0' else  -- LOW-NIBLE := x".A"
      UpTimeData(15 downto 8)    when RegSel = "1011" AND n_CS = '0' AND n_RD = '0' else  -- LOW-NIBLE := x".B"
      UpTimeData(23 downto 16)   when RegSel = "1100" AND n_CS = '0' AND n_RD = '0' else  -- LOW-NIBLE := x".C"
      UpTimeData(31 downto 24)   when RegSel = "1101" AND n_CS = '0' AND n_RD = '0' else  -- LOW-NIBLE := x".D"

     -- Get data from 16-bit RND-Generator
      RND16(7 downto 0)          when RegSel = "1110" AND n_CS = '0' AND n_RD = '0' else  -- LByte := x".E"
      RND16(15 downto 8)         when RegSel = "1111" AND n_CS = '0' AND n_RD = '0' else  -- HByte := x".F"

      (others => '1');

end rtl;
