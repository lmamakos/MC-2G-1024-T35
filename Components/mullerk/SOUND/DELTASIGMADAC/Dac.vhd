-------------------------------------------------------------------------------
--
-- Delta-Sigma DAC
--
-- $Id: dac.vhd,v 1.1 2006/05/10 20:57:06 arnim Exp $
--
-- Refer to Xilinx Application Note XAPP154.
--
-- This DAC requires an external RC low-pass filter:
--
--   dac_o 0---XXXXX---+---0 analog audio
--              3k3    |
--                    === 4n7
--                     |
--                    GND
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Dac is
   generic
   (
      SAMPLE_WIDTH : integer := 8
   );
   port
   (
      clock : in std_logic;
      clken : in std_logic;
      reset : in std_logic;
      dac_i : in std_logic_vector(SAMPLE_WIDTH-1 downto 0);
      dac_o : out std_logic
   );
end Dac;

architecture rtl of Dac is

   signal DACout_q     : std_logic;
   signal DeltaAdder_s : unsigned(SAMPLE_WIDTH+1 downto 0);
   signal SigmaAdder_s : unsigned(SAMPLE_WIDTH+1 downto 0);
   signal SigmaLatch_q : unsigned(SAMPLE_WIDTH+1 downto 0);
   signal DeltaB_s     : unsigned(SAMPLE_WIDTH+1 downto 0);

begin

   DeltaB_s(SAMPLE_WIDTH+1 downto SAMPLE_WIDTH) <= SigmaLatch_q(SAMPLE_WIDTH+1) & SigmaLatch_q(SAMPLE_WIDTH+1);
   DeltaB_s(SAMPLE_WIDTH-1 downto 0) <= (others => '0');
   DeltaAdder_s <= unsigned('0' & '0' & dac_i) + DeltaB_s;
   SigmaAdder_s <= DeltaAdder_s + SigmaLatch_q;
   dac_o <= DACout_q;

   seq: process (clock, reset)
   begin
      if reset='1' then

         SigmaLatch_q <= to_unsigned(2**(SAMPLE_WIDTH), SigmaLatch_q'length);
         DACout_q     <= '0';

      elsif rising_edge(clock) then

         if clken='1' then

            SigmaLatch_q <= SigmaAdder_s;
            DACout_q     <= SigmaLatch_q(SAMPLE_WIDTH+1);

         end if;

      end if;
   end process;


end rtl;
