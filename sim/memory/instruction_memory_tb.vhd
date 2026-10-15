-- Banc d'essai de la mémoire d'instructions : dix écritures, puis dix lectures.
-- Les signaux sont à observer en simulation; aucune assertion de référence.

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.RISC_utils.all;
use work.all;

entity instruction_memory_tb is
end instruction_memory_tb;

architecture testbench of instruction_memory_tb is
  constant periode  : time                                   := 10 ns;
  signal clk        : std_logic                              := '0';
  signal addr       : unsigned(RISC_MEMI_W - 1 downto 0) := (others => '0');
  signal wr         : std_logic;
  signal donnee_out : unsigned(RISC_GPIO_W - 1 downto 0);
  signal donnee_in  : unsigned(RISC_GPIO_W - 1 downto 0);
begin
  clk <= not(clk) after periode / 2;

  UUT : entity RISC_ROM
    port map (
      clk      => clk,
      i_addr   => addr,
      i_wr     => wr,
      i_donnee => donnee_in,
      o_donnee => donnee_out);

  process(clk)
    variable cnt : integer := 0;
    variable val : integer := 16#CAFE#;
  begin
    if falling_edge(clk) then
      if cnt < 10 then
        wr        <= '1';
        addr      <= to_unsigned(cnt, RISC_MEMI_W);
        donnee_in <= to_unsigned(val, RISC_GPIO_W);
        val       := val + 1;
      elsif cnt < 20 then
        wr   <= '0';
        addr <= to_unsigned(cnt - 10, RISC_MEMI_W);
      else
        report "Done" severity failure;
      end if;
      cnt := cnt + 1;
    end if;
  end process;
end testbench;
