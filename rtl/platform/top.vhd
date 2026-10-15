-- Assemblage FPGA PYNQ/Zynq : cœur RISC, mémoire et chargeur AXI-Stream.
-- Dépend du bloc zynq_wrapper fourni par le projet matériel Vivado.

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use WORK.RISC_utils.all;
use WORK.all;

entity top is
  port (
    o_led_top  : out std_logic_vector(3 downto 0);
    i_btns_top : in  std_logic_vector(3 downto 0)
  );
end top;

architecture arch of top is
  signal clk     : std_logic;
  signal poreset : std_logic;
  signal rst     : std_logic;

  -- Liaison cœur / mémoire d'instructions.
  signal risc_instruction : unsigned(RISC_GPIO_W - 1 downto 0);
  signal risc_instr_addr  : unsigned(RISC_MEMI_W - 1 downto 0);

  -- Données et validation des GPIO du cœur.
  signal risc_gpio_out_ok : std_logic;
  signal risc_gpio_out    : signed(RISC_GPIO_W - 1 downto 0);
  signal risc_gpio_in_ok  : std_logic;
  signal risc_gpio_in     : signed(RISC_GPIO_W - 1 downto 0);
  signal risc_reset       : std_logic := '0';

  -- Flux AXI depuis Zynq et commandes d'écriture de la mémoire.
  signal s2r_last       : std_logic;
  signal s2r_valid      : std_logic;
  signal s2r_ready      : std_logic;
  signal s2r_donnee_in  : std_logic_vector(32 - 1 downto 0);
  signal s2r_donnee_out : unsigned(RISC_GPIO_W - 1 downto 0);
  signal s2r_addr_out   : unsigned(RISC_MEMI_W - 1 downto 0);
  signal s2r_wr         : std_logic;
  signal rom_addr_in    : unsigned(RISC_MEMI_W - 1 downto 0);

  -- Registres de données et de contrôle de la plateforme Zynq.
  signal data_out, data_in : std_logic_vector(31 downto 0);
  signal zynq_control     : std_logic_vector(31 downto 0);
begin
  -- Contrôle Zynq : bit 0 = donnée GPIO valide, bit 1 = reset du cœur,
  -- bit 2 = reset du chargeur. Le bouton 0 et poreset activent les deux resets.
  rst        <= poreset or i_btns_top(0) or zynq_control(2);
  risc_reset <= poreset or i_btns_top(0) or zynq_control(1);

  -- Réinitialisation à la mise sous tension.
  por_inst : entity power_on_reset
    port map (
      clk       => clk,
      reset_out => poreset);

  -- Cœur du processeur.
  risc_gpio_in_ok <= zynq_control(0);
  RISC_inst : entity RISC(RISCV)
    port map (
      reset         => risc_reset,
      clk           => clk,
      i_GPIO        => risc_gpio_in,
      i_GPIO_valide => risc_gpio_in_ok,
      i_inst        => risc_instruction,
      o_inst_addr   => risc_instr_addr,
      o_GPIO        => risc_gpio_out,
      o_GPIO_valide => risc_gpio_out_ok);

  -- Priorité à l'adresse du chargeur lorsque s2r_valid est actif;
  -- sinon, la mémoire est adressée par le compteur de programme du cœur.
  rom_addr_in <= s2r_addr_out when s2r_valid else risc_instr_addr;

  -- Mémoire du programme, chargeable depuis la plateforme.
  ROM_inst : entity RISC_ROM(arch)
    port map (
      clk      => clk,
      i_addr   => rom_addr_in,
      i_wr     => s2r_wr,
      i_donnee => s2r_donnee_out,
      o_donnee => risc_instruction);

  -- Conversion du flux AXI en écritures séquentielles.
  S2R_inst : entity AXIS2ROM(arch)
    generic map (
      DATA_IN_W  => 32,
      DATA_OUT_W => RISC_GPIO_W,
      ADDR_W     => RISC_MEMI_W)
    port map (
      clk      => clk,
      reset    => rst,
      i_donnee => s2r_donnee_in,
      i_last   => s2r_last,
      i_valid  => s2r_valid,
      o_ready  => s2r_ready,
      o_donnee => s2r_donnee_out,
      o_addr   => s2r_addr_out,
      o_wr     => s2r_wr);

  -- Adaptation entre les GPIO 32 bits du Zynq et la largeur du cœur.
  risc_gpio_in <= resize(signed(data_in), RISC_GPIO_W);
  data_out     <= std_logic_vector(resize(risc_gpio_out, 32));

  -- Le wrapper fournit l'horloge, les GPIO et l'interface AXI-Stream.
  zynq : entity zynq_wrapper(STRUCTURE)
    port map (
      clk              => clk,
      to_zynq_data      => data_out,
      from_zynq_data    => data_in,
      from_zynq_control => zynq_control,
      from_zynq_tdata   => s2r_donnee_in,
      from_zynq_tlast   => s2r_last,
      from_zynq_tready  => s2r_ready,
      from_zynq_tvalid  => s2r_valid
    );
end arch;
