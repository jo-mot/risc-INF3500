-- Banc d'essai du chargeur AXI-Stream : flux avec interruption de valid.
-- Les signaux sont à observer en simulation; aucune assertion de référence.

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.all;

entity AXIS2ROM_tb is
  generic (
    DATA_W : positive := 32;
    ADDR_W : positive := 8
    );
end AXIS2ROM_tb;

architecture tb of AXIS2ROM_tb is
  constant periode      : time                                  := 10 ns;
  constant MAX_CNT      : integer                               := 100;
  signal clk            : std_logic                             := '0';
  signal reset          : std_logic                             := '0';
  signal uut_donnee_in  : std_logic_vector(DATA_W - 1 downto 0) := (others => '1');
  signal uut_donnee_out : unsigned(DATA_W - 1 downto 0);
  signal uut_valid      : std_logic;
  signal uut_ready      : std_logic;
  signal uut_last       : std_logic;
  signal uut_wr         : std_logic;
  signal uut_addr_out   : unsigned(ADDR_W - 1 downto 0);
begin
  clk   <= not(clk) after periode / 2;
  reset <= '1'      after 0 ns, '0' after 9 * periode / 4;

  UUT : entity AXIS2ROM(arch)
    generic map (
      DATA_IN_W  => DATA_W,
      DATA_OUT_W => DATA_W,
      ADDR_W     => ADDR_W)
    port map (
      clk      => clk,
      reset    => reset,
      i_donnee => uut_donnee_in,
      i_last   => uut_last,
      i_valid  => uut_valid,
      o_ready  => uut_ready,
      o_donnee => uut_donnee_out,
      o_addr   => uut_addr_out,
      o_wr     => uut_wr);

  process(clk, reset)
    variable cnt : integer := 0;
  begin
    if reset = '1' then
      cnt       := 0;
      uut_valid <= '0';
    elsif rising_edge(clk) then
      if cnt > 10 and cnt < 20 then
        uut_valid <= '0';
      else
        uut_valid <= '1';
      end if;
      if cnt = MAX_CNT - 1 then
        uut_last <= '1';
      elsif cnt = MAX_CNT then
        report "Done" severity failure;
      else
        uut_last <= '0';
      end if;
      if uut_ready = '1' then
        cnt := cnt + 1;
      end if;
      uut_donnee_in <= std_logic_vector(to_unsigned(cnt, DATA_W));
    end if;
  end process;
end tb;
