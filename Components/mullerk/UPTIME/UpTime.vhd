-- ---------------------------------------------------------------------
-- UpTime-Counter
-- ---------------------------------------------------------------------
library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use ieee.std_logic_unsigned.all;

entity UpTime is
   port (
      Clk1ms   : in  std_logic;                    -- 1ms clock for UptimeCounter
      n_reset  : in  std_logic;
      n_WR     : in  std_logic;                    -- n_ioWR
      n_RD     : in  std_logic;                    -- n_ioWR
      n_CS     : in  std_logic;                    -- n_InterfaceJCS
      regSel   : in  std_logic_vector(3 downto 0);
      datain   : in  std_logic_vector(1 downto 0);
      dataOut  : out std_logic_vector(31 downto 0)
   );
end UpTime;

architecture rtl of UpTime is

signal IndexReg      : std_logic_vector(1 downto 0) := (others=>'0'); -- Index-Register for Storage-Reg. Readback
signal UpTimeCounter : std_logic_vector(31 downto 0);                 -- Counter-Register for Uptime
signal UpTimeStore0  : std_logic_vector(31 downto 0);                 -- Latch-Register0 for reading Uptime0
signal UpTimeStore1  : std_logic_vector(31 downto 0);                 -- Latch-Register1 for reading Uptime1
signal UpTimeStore2  : std_logic_vector(31 downto 0);                 -- Latch-Register2 for reading Uptime2
signal UpTimeStore3  : std_logic_vector(31 downto 0);                 -- Latch-Register3 for reading Uptime3

begin

   DataOut <=
      -- Reading UpTimeCounter, Index-Reg. controlled
      UpTimeStore0 when n_RD = '0' AND n_CS = '0' AND IndexReg = "00" else
      UpTimeStore1 when n_RD = '0' AND n_CS = '0' AND IndexReg = "01" else
      UpTimeStore2 when n_RD = '0' AND n_CS = '0' AND IndexReg = "10" else
      UpTimeStore3 when n_RD = '0' AND n_CS = '0' AND IndexReg = "11" else

      (others => '1');

      -- Uptime-Counter, counts the 1ms-Ticks,
      -- Clear Uptime-Counter by writing to High-Byte of counter
      process (Clk1ms,n_RESET,regSel,dataIn,n_WR,n_CS)
        begin
           --  <-- RESET -->      <--  Write to HByte of Counter to clear  ------------------>
           if (n_RESET = '0') OR (regSel = x"D" AND dataIn = "00" AND n_WR = '0' AND n_CS = '0') then
              UptimeCounter <= (others=>'0');
           else
              if (falling_edge(Clk1ms)) then          -- 1kHz Clock for Uptime-CNT
                 UptimeCounter <= UptimeCounter +1;   -- We use a 32-bit counter for 1ms * 2^32 := 4294967,296 sec
              end if;                                 --    so max. Uptime before overflow is:
           end if;                                    --       4294967,296sec / 86400sec :=  49d 17h 2m 47,296s
        end process;

      -- Latch UpTime-Counter with WR to Port $BA and Databus = 'RegNum'
      process(n_WR,RegSel,n_CS)
      begin
         if (RegSel = x"A" AND n_CS = '0') then
             if rising_edge(n_WR) then
                if DataIn ="00" then
                   UpTimeStore0 <= UpTimeCounter;
                elsif DataIn ="01" then
                   UpTimeStore1 <= UpTimeCounter;
                elsif DataIn ="10" then
                   UpTimeStore2 <= UpTimeCounter;
                elsif DataIn ="11" then
                   UpTimeStore3 <= UpTimeCounter;
                end if;
             end if;
          end if;
      end process;

      -- Latch IndexReg with WR to Port $BA or $BB
      process(n_WR, RegSel, n_CS)
      begin
        if (RegSel(3 downto 1) = "101") AND n_CS = '0' then
           if rising_edge(n_WR) then
              IndexReg <= DataIn;
           end if;
        end if;
      end process;

end rtl;
