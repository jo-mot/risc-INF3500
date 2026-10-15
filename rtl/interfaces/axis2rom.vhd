-- Chargement séquentiel de la mémoire d'instructions depuis AXI-Stream.

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.all;

entity AXIS2ROM is
  generic (
    DATA_IN_W  : positive := 32;
    DATA_OUT_W : positive := 32;
    ADDR_W     : positive := 8
    );
  port (
    clk, reset : in  std_logic;
    i_donnee   : in  std_logic_vector(DATA_IN_W - 1 downto 0);
    i_last     : in  std_logic;
    i_valid    : in  std_logic;
    o_ready    : out std_logic;
    o_donnee   : out unsigned(DATA_OUT_W - 1 downto 0);
    o_addr     : out unsigned(ADDR_W - 1 downto 0);
    o_wr       : out std_logic
    );
end AXIS2ROM;

architecture arch of AXIS2ROM is
  signal adresse : integer := 0;
  signal ready   : std_logic;
begin
  o_ready  <= ready;
  o_addr   <= to_unsigned(adresse, ADDR_W);
  o_donnee <= resize(unsigned(i_donnee), DATA_OUT_W);
  -- Une écriture est demandée lorsque valid et ready sont actifs.
  o_wr     <= i_valid and ready;

  -- Adresse remise à zéro par reset, puis incrémentée lorsque i_valid est actif.
  -- Le port i_last est présent dans l'interface mais inutilisé dans ce design.
  process(clk, reset)
  begin
    if reset = '1' then
      ready   <= '0';
      adresse <= 0;
    elsif rising_edge(clk) then
      ready <= '1';
      if i_valid = '1' then
        adresse <= adresse + 1;
      end if;
    end if;
  end process;
end arch;
