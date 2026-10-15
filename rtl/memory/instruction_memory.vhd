-- Mémoire d'instructions : lecture asynchrone, écriture synchrone.
-- Le nom historique RISC_ROM est conservé; le contenu est chargeable.

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.RISC_utils.all;

entity RISC_ROM is
  port (
    clk      : in  std_logic;
    i_addr   : in  unsigned(RISC_MEMI_W - 1 downto 0);
    -- Écriture par le chargeur AXI-Stream; le cœur lit uniquement la mémoire.
    i_wr     : in  std_logic;
    i_donnee : in  unsigned(RISC_GPIO_W - 1 downto 0);
    o_donnee : out unsigned(RISC_GPIO_W - 1 downto 0)
  );
end RISC_ROM;

architecture arch of RISC_ROM is
  type memoireInstructions_t is
    array(0 to 2 ** RISC_MEMI_W - 1) of unsigned(RISC_GPIO_W - 1 downto 0);
  signal memoire : memoireInstructions_t := (others => (others => '0'));
begin
  o_donnee <= memoire(to_integer(i_addr));

  process(clk)
  begin
    if rising_edge(clk) then
      if i_wr = '1' then
        memoire(to_integer(i_addr)) <= i_donnee;
      end if;
    end if;
  end process;

end arch;
