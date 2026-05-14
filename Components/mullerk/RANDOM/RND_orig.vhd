library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity LFSR is
    Port ( clk     : in  std_logic;
           value16 : out std_logic_vector (15 downto 0);
           value32 : out  std_logic_vector (31 downto 0);
           value8  : out  std_logic_vector ( 7 downto 0));
end LFSR;

architecture Behavioral of LFSR is
   signal rnd8  : std_logic_vector ( 7 downto 0) := (others=>'0');
   signal rnd16 : std_logic_vector (15 downto 0) := (others=>'0');
   signal rnd32 : std_logic_vector (31 downto 0) := (others=>'0');

begin
   process begin
      wait until rising_edge(CLK);
       -- 8Bit
       rnd8(7 downto 1) <= rnd8(6 downto 0) ;
       rnd8(0) <= not(rnd8(7) XOR rnd8(6) XOR rnd8(4));
       -- 16Bit
       rnd16(15 downto 1) <= rnd16(14 downto 0) ;
       rnd16(0) <= not(rnd16(15) XOR rnd16(14) XOR rnd16(13) XOR rnd16(4));
       -- 32 Bit
       rnd32(31 downto 1) <= rnd32(30 downto 0) ;
       rnd32(0) <= not(rnd32(31) XOR rnd32(22) XOR rnd32(2) XOR rnd32(1));
   end process;
   value8  <= rnd8;
   value16 <= rnd16;
   value32 <= rnd32;
end Behavioral;
