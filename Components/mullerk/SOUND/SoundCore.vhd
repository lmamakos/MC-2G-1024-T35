library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity SoundCore is
    Port
    (
        clk_psg           : in  std_logic;                        -- Sound clock
        clk_dac           : in  std_logic;                        -- 50MHz system clock
        n_reset           : in  std_logic;
        n_cs_L            : in  std_logic;                        -- Chip-Select left channel
        n_cs_R            : in  std_logic;                        -- Chip-Select right channel
        n_wr              : in  std_logic;                        -- Chip-Write
        EnSndHW           : in  std_logic_vector(4 downto 0);     -- switch SndHW OFF/ON Bit: PSG & DAC !
        psg_data_i        : in  std_logic_vector(7 downto 0);     -- Sound data for psg
        psg_stat_o        : out std_logic;                        -- PSG READY-Bit OR'ed from left & right PSG
        dac_L_o           : out std_logic;                        -- PWM-Audio left
        dac_R_o           : out std_logic                         -- PWM-Audio right
    );
end SoundCore;

architecture Behavioral of SoundCore is
    signal psg_aout_L_o :   signed(0 to 7);
    signal psg_aout_R_o :   signed(0 to 7);
    signal psg_data_i_L :   std_logic_vector(7 downto 0);
    signal psg_data_i_R :   std_logic_vector(7 downto 0);
    signal dac_L_i :        std_logic_vector(7 downto 0);
    signal dac_R_i :        std_logic_vector(7 downto 0);
    signal dac_L_i_mux_o :  std_logic_vector(7 downto 0);
    signal dac_R_i_mux_o :  std_logic_vector(7 downto 0);
    signal psg_ce_L_n :     std_logic;
    signal psg_ce_R_n :     std_logic;
    signal psg_we_n :       std_logic;
    signal psg_ready_L :    std_logic;
    signal psg_ready_R :    std_logic;

begin
    SN76489_L : entity work.SN76489_top
    GENERIC MAP
    (
        clock_div_16_g => 1
    )
    -- connect left SN76489 to port ...
    PORT MAP
    (
        clock_i    => clk_psg,
        clock_en_i => EnSndHW(3),       -- For Sound-Hardware OFF = '0' / ON = '1'
        res_n_i    => n_reset,
        ce_n_i     => psg_ce_L_n OR (NOT EnSndHW(3)) OR EnSndHW(4),
        we_n_i     => psg_we_n,
        ready_o    => psg_ready_L,      -- Data-WR Ready-Bit from PSG
        d_i        => psg_data_i,       -- Sound-Data from CPU
        aout_o     => psg_aout_L_o      -- Sound-Bytes from PSG for DAC
    );
    dac_L_i <= std_logic_vector(unsigned(std_logic_vector(psg_aout_L_o)) + 128);

    -- Interface left DAC to left PSG ...
    DAC_L : entity work.dac
    PORT MAP
    (
        clock => clk_dac,
        clken => EnSndHW(2),
        reset => NOT n_reset,
        dac_i => dac_L_i_mux_o,
        dac_o => dac_L_o
    );

    SN76489_R : entity work.SN76489_top
    GENERIC MAP
    (
        clock_div_16_g => 1
    )
    -- connect right SN76489 to port ...
    PORT MAP
    (
        clock_i    => clk_psg,
        clock_en_i => EnSndHW(1),         -- For Sound-Hardware OFF = '0' / ON = '1'
        res_n_i    => n_reset,
        ce_n_i     => psg_ce_R_n OR (NOT EnSndHW(1) OR EnSndHW(4)),
        we_n_i     => psg_we_n,
        ready_o    => psg_ready_R,        -- Data-WR Ready-Bit from PSG
        d_i        => psg_data_i,         -- Sound-Data from CPU
        aout_o     => psg_aout_R_o        -- Sound-Bytes from PSG for DAC
    );
    dac_R_i <= std_logic_vector(unsigned(std_logic_vector(psg_aout_R_o)) + 128);

    -- Interface right DAC to right PSG ...
    DAC_R : entity work.dac
    PORT MAP
    (
        clock => clk_dac,
        clken => EnSndHW(0),
        reset => NOT n_reset,
        dac_i => dac_R_i_mux_o,
        dac_o => dac_R_o
    );

    -- connect control signals...
    psg_ce_L_n <= n_cs_L;
    psg_ce_R_n <= n_cs_R;
    psg_we_n   <= n_wr;
    psg_stat_o <= psg_ready_L AND psg_ready_R;

    -- multiplex left dac-input to left chan. depending on EnSndHW(4)-Bit
    dac_L_i_mux_o <= dac_L_i when (EnSndHW(4)= '0') else psg_data_i_L;

    -- multiplex right dac-input to right chan. depending on EnSndHW(4)-Bit
    dac_R_i_mux_o <= dac_R_i when (EnSndHW(4)= '0') else psg_data_i_R;

    ---------------------------------------------------------------------
    -- REMARK: the both DAC Input-Register will store each incoming byte
    -- that is written to the PSG Data-Inputs, regardless whether we are
    -- in PSG- or DAC-Mode ! So, if switching to DAC-Mode a clear step
    -- sequence is recommended to use:
    --          out &H98,&H80  ; switch to DAC-Mode, PSG's/DAC's = OFF
    --          out &HA8,&H00  ; write '00' to left  DAC input-register
    --          out &HA9,&H00  ; write '00' to right DAC input-register
    --          out &H98,&H85  ; switch in DAC-Mode both DAC's to ON
    --
    -- Bit-Ordering for EnSndHW(4 downto 0):
    -- When Read/Write to Port $98, Bit7 is Routed to Bit4 of Bit-Vector !
    -- Address $98 WRITE:
    --     Bit4 := Data to PSG/DAC:  PSG = '0', DAC = '1'
    --     Bit3 := Left  PSG      :  OFF = '0',  ON = '1'
    --     Bit2 := Left  DAC      :  OFF = '0',  ON = '1'
    --     Bit1 := Right PSG      :  OFF = '0',  ON = '1'
    --     Bit0 := Right DAC      :  OFF = '0',  ON = '1'
    ---------------------------------------------------------------------
    -- store incomming data from cpu into
    -- dac-register for left channel
    process(psg_ce_L_n, n_reset,EnSndHW(4) )
    begin
        if (n_reset = '0') then
            psg_data_i_L <= (others => '0');
        elsif rising_edge(psg_ce_L_n) then
              psg_data_i_L <= psg_data_i;
        end if;
    end process;

    -- store incomming data from cpu into
    -- dac-register for right channel
    process(psg_ce_R_n, n_reset, EnSndHW(4))
    begin
        if (n_reset = '0') then
            psg_data_i_R <= (others => '0');
        elsif rising_edge(psg_ce_R_n) then
              psg_data_i_R <= psg_data_i;
        end if;
    end process;

end Behavioral;

