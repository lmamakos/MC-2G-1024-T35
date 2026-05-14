library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_unsigned.all;


-- Read is done in Byte chunks:
--   Port $BE is Low-Byte on n_RD
--   Port $BF is High-Byte on n_RD
-- Write access to Port $BE stores RND-data in a latch in preparation
--   for subsequent data read, so complete action is:
--      OUT(&HBE),0:                    REM grep a Number from RND-Gen.
--      NUM = INP(&HBF)*256 + INP($BE): REM Store RND-Number to Variable

entity LFSR is
    Port ( clk      : in  std_logic;
           n_RD     : in  std_logic;
           n_WR     : in  std_logic;
           n_CS     : in  std_logic;
           RegSEL   : in  std_logic_vector (3 downto 0);
           Dataout  : out std_logic_vector (15 downto 0)
          );
     end LFSR;

architecture Behavioral of LFSR is
   signal Store16 : std_logic_vector (15 downto 0);
   signal rnd16   : std_logic_vector (15 downto 0) := x"0002";
   signal rndnum  : std_logic;

begin

   -- shift rnd16 one bit to the left
   process (CLK,rnd16)
     begin
       if rnd16 = x"FFFF" then
          rnd16(1) <= rnd16(1) XOR '1';
		 elsif  rnd16 = x"0000" then
          rnd16(1) <= rnd16(1) OR '1';
       elsif falling_edge(CLK) then
          -- 16Bit
          rnd16(15 downto 1) <= rnd16(14 downto 0);
       end if;
     end process;

   -- create new rnd16(0)-bit and write to shift register bit0
   process (CLK)
     begin
       if rising_edge(CLK) then
          -- 16Bit
          rndnum <= (rnd16(15) XOR rnd16(14) XOR rnd16(12) XOR rnd16(3) XOR '1');
          rnd16(0) <= rndnum;
       end if;
     end process;

   -- transfer RND-Value to Latch-Register with WR to Port $BE
   process (n_CS, n_WR, RegSel)
     begin
       if RegSel = x"E" AND n_CS = '0' then
          if rising_edge(n_WR) then
             store16 <= rnd16;
          end if;
       end if;
   end process;

    dataout <= store16;

end Behavioral;
