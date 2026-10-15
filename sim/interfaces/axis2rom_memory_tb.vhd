-- Banc d'intégration du chargeur AXI-Stream et de la mémoire d'instructions.
-- Première phase : chargement. Seconde phase : lecture des adresses.

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.RISC_utils.all;
use work.all;

entity AXIS2ROM_memory_tb is
end AXIS2ROM_memory_tb;

architecture arch of AXIS2ROM_memory_tb is
  constant periode      : time                                           := 10 ns;
  constant MAX_CNT      : integer                                        := 100;
  signal clk            : std_logic                                      := '0';
  signal reset          : std_logic                                      := '0';
  signal rom_donnee_out : unsigned(RISC_GPIO_W - 1 downto 0)         := (others => '1');
  signal rom_addr_in    : unsigned(RISC_MEMI_W - 1 downto 0)         := (others => '1');
  signal s2r_donnee_in  : std_logic_vector(RISC_GPIO_W - 1 downto 0) := (others => '1');
  signal s2r_donnee_out : unsigned(RISC_GPIO_W - 1 downto 0);
  signal s2r_valid      : std_logic;
  signal s2r_ready      : std_logic;
  signal s2r_last       : std_logic;
  signal s2r_wr         : std_logic;
  signal s2r_addr_out   : unsigned(RISC_MEMI_W - 1 downto 0);
  signal cnt            : integer                                        := 0;
begin
  clk         <= not(clk) after periode / 2;
  reset       <= '1'      after 0 ns, '0' after 9 * periode / 4;
  rom_addr_in <= s2r_addr_out when cnt < MAX_CNT / 2
                 else to_unsigned(cnt - MAX_CNT / 2, RISC_MEMI_W);
  s2r_donnee_in <= std_logic_vector(to_signed(cnt, RISC_GPIO_W));

  ROM : entity RISC_ROM
    port map (
      clk      => clk,
      i_addr   => rom_addr_in,
      i_wr     => s2r_wr,
      i_donnee => s2r_donnee_out,
      o_donnee => rom_donnee_out);

  S2R : entity AXIS2ROM
    generic map (
      DATA_IN_W  => RISC_GPIO_W,
      DATA_OUT_W => RISC_GPIO_W,
      ADDR_W     => RISC_MEMI_W)
    port map (
      clk      => clk,
      reset    => reset,
      i_donnee => s2r_donnee_in,
      i_last   => s2r_last,
      i_valid  => s2r_valid,
      o_ready  => s2r_ready,
      o_donnee => s2r_donnee_out,
      o_addr   => s2r_addr_out,
      o_wr     => s2r_wr);

  process(clk, reset)
  begin
    if reset = '1' then
      cnt       <= -1;
      s2r_valid <= '0';
    elsif falling_edge(clk) then
      if cnt < MAX_CNT / 2 then
        if cnt > 10 and cnt < 20 then
          s2r_valid <= '0';
        else
          s2r_valid <= '1';
        end if;

        if cnt = MAX_CNT / 2 - 1 then
          s2r_last <= '1';
        else
          s2r_last <= '0';
        end if;

        if s2r_ready = '1' then
          cnt <= cnt + 1;
        end if;
      else
        s2r_valid <= '0';
        if cnt = MAX_CNT then
          report "Done" severity failure;
        end if;
        cnt <= cnt + 1;
      end if;
    end if;
  end process;
end arch;
