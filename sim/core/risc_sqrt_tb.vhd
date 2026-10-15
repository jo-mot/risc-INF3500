-- Banc d'essai du RISC : racine carrée entière par dichotomie.
-- Programme encodé dans memoire_inst; entrées et sorties par fichiers.

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.MATH_REAL.all;
use STD.TEXTIO.all;
use IEEE.STD_LOGIC_TEXTIO.all;
use work.all;
use work.RISC_utils.all;

entity RISC_sqrt_tb is
end;

architecture arch_tb of RISC_sqrt_tb is
  type memoireInstSimulation is
    array(0 to 2 ** RISC_MEMI_W - 1) of unsigned(RISC_GPIO_W - 1 downto 0);

  -- Programme exécuté par le cœur; les autres adresses contiennent NOP.
  constant memoire_inst : memoireInstSimulation :=
    (

      -- R0 reçoit l'entrée GPIO.
      0  => inst_to_unsigned(gen_inst(memoire, lireGPIO_in, 0, 0, 0)),

      -- Borne basse R1 = 0.
      1  => inst_to_unsigned(gen_inst(reg_valeur, passeB, 1, 0, 0)),

      -- Borne haute R2 = 32767.
      2  => inst_to_unsigned(gen_inst(reg_valeur, passeB, 2, 0, 32767)),

      -- Compteur R5 = 16.
      3  => inst_to_unsigned(gen_inst(reg_valeur, passeB, 5, 0, 16)),

      -- R7 = 0 pour les comparaisons.
      4  => inst_to_unsigned(gen_inst(reg_valeur, passeB, 7, 0, 0)),

      -- Début de boucle : somme des bornes.
      5  => inst_to_unsigned(gen_inst(reg, AplusB, 6, 1, 2)),

      -- R3 = milieu de l'intervalle.
      6  => inst_to_unsigned(gen_inst(reg, Adiv2, 3, 6, 0)),

      -- R4 = carré du milieu.
      7  => inst_to_unsigned(gen_inst(reg, AmultB, 4, 3, 3)),

      -- Si R4 = R0, sortie à l'adresse 15.
      8  => inst_to_unsigned(gen_inst(branchement, egal, 0, 4, 7)),

      -- Si R4 < R0, mise à jour de la borne basse à l'adresse 12.
      9  => inst_to_unsigned(gen_inst(branchement, ppq, 0, 4, 3)),

      -- Mise à jour de la borne haute.
      10 => inst_to_unsigned(gen_inst(reg, passeA, 2, 3, 0)),

      -- Saut à l'adresse 13.
      11 => inst_to_unsigned(gen_inst(branchement, toujours, 0, 0, 2)),

      -- Mise à jour de la borne basse.
      12 => inst_to_unsigned(gen_inst(reg, passeA, 1, 3, 0)),

      -- Décrément du compteur.
      13 => inst_to_unsigned(gen_inst(reg_valeur, AmoinsB, 5, 5, 1)),

      -- Si R5 > 0, retour à l'adresse 5.
      14 => inst_to_unsigned(gen_inst(branchement, pgq, 7, 5, -9)),

      -- Écriture du résultat sur GPIO.
      15 => inst_to_unsigned(gen_inst(memoire, ecrireGPIO_out, 3, 0, 0)),

      -- Arrêt du programme.
      16 => inst_to_unsigned(STOP),

      others => inst_to_unsigned(NOP));

  -- Horloge de simulation de période 10 ns.
  constant periode         : time                                 := 10 ns;
  signal clk               : std_logic                            := '0';
  signal uut_reset         : std_logic;
  signal GPIO_in, GPIO_out : signed(RISC_GPIO_W - 1 downto 0);
  signal GPIO_in_valide    : std_logic                            := '0';
  signal GPIO_out_valide   : std_logic;
  signal instruction       : unsigned(RISC_GPIO_W - 1 downto 0);
  signal inst_addr         : unsigned(RISC_MEMI_W - 1 downto 0);
  -- Les noms des fichiers sont relatifs au répertoire de lancement.
  file fichier_entrees     : text;
  file fichier_sorties     : text;
  signal vecteur_test      : signed(RISC_GPIO_W - 1 downto 0) := (others => '0');
begin
  clk         <= not clk after periode / 2;
  instruction <= memoire_inst(to_integer(inst_addr));
  GPIO_in     <= vecteur_test;

  -- Processeur relié à une mémoire d'instructions simulée.
  UUT : entity RISC(RISCV)
    port map (
      clk           => clk,
      reset         => uut_reset,
      i_GPIO        => GPIO_in,
      i_GPIO_valide => GPIO_in_valide,
      i_inst        => instruction,
      o_inst_addr   => inst_addr,
      o_GPIO        => GPIO_out,
      o_GPIO_valide => GPIO_out_valide
    );

  test : process
    constant reset_cnt     : integer := 5;
    variable ligne_entrees : line;
    variable entree_int    : integer;

    variable ligne_sorties : line;

  begin
    -- Une entrée entière par ligne; une sortie écrite par entrée.
    file_open(fichier_entrees, "dichotomie_vecs.txt", read_mode);
    file_open(fichier_sorties, "dichotomie_out.txt", write_mode);
    while not(endfile(fichier_entrees)) loop
      readline(fichier_entrees, ligne_entrees);
      read(ligne_entrees, entree_int);
      vecteur_test   <= to_signed(entree_int, RISC_GPIO_W);
      -- Relâchement du reset sur un front descendant.
      uut_reset      <= '1';
      wait for periode * reset_cnt + periode / 2;
      uut_reset      <= '0';
      -- Validation de l'entrée pendant un cycle, puis attente du résultat.
      GPIO_in_valide <= '1';
      wait for periode;
      GPIO_in_valide <= '0';
      while GPIO_out_valide = '0' loop
        wait for periode;
      end loop;

      -- Comparaison à floor(sqrt(entrée)) avec une tolérance de 1.
      assert abs(to_integer(GPIO_out) - integer(floor(sqrt(real(entree_int))))) <= 1
        report "Erreur racine : entree="  & integer'image(entree_int) &
               " attendu=" & integer'image(integer(floor(sqrt(real(entree_int))))) &
               " obtenu="  & integer'image(to_integer(GPIO_out))
        severity failure;

      report "Sortie : " & integer'image(to_integer(GPIO_out)) severity note;
      write(ligne_sorties, to_integer(GPIO_out));
      writeline(fichier_sorties, ligne_sorties);
    end loop;
    file_close(fichier_entrees);
    file_close(fichier_sorties);

    -- Convention d'arrêt du banc d'essai d'origine : severity failure.
    report "Fin" severity failure;
  end process;
end;
