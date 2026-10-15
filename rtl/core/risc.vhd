-- Cœur RISC pédagogique : décodage, chemin de données et contrôle.
-- Mémoire d'instructions externe, mémoire de données interne.

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use WORK.RISC_utils.all;

entity RISC is
  port (
    reset, clk    : in  std_logic;
    i_GPIO        : in  signed(RISC_GPIO_W - 1 downto 0);
    i_GPIO_valide : in  std_logic;
    i_inst        : in  unsigned(RISC_GPIO_W - 1 downto 0);
    o_inst_addr   : out unsigned(RISC_MEMI_W - 1 downto 0);
    o_GPIO        : out signed(RISC_GPIO_W - 1 downto 0);
    o_GPIO_valide : out std_logic
  );
end RISC;

architecture RISCV of RISC is
  -- Champs de l'instruction courante.
  signal iCat    : natural range 0 to n_instr - 1;
  signal iDet    : natural range 0 to n_detail - 1;
  signal iReg1   : unsigned(RISC_AREG_W - 1 downto 0);
  signal iReg2   : unsigned(RISC_AREG_W - 1 downto 0);
  signal iVal    : signed(inst_val_w - 1 downto 0);
  signal addrReg : unsigned(RISC_AREG_W - 1 downto 0);

  -- Banc de registres et multiplexeur d'écriture.
  signal fichierRegistres           : fichierRegistres_t;
  signal entreeReg, A, B            : signed(RISC_GPIO_W - 1 downto 0);
  signal choixA, choixB, choixCharge : unsigned(RISC_AREG_W - 1 downto 0);
  signal chargeRegistre             : std_logic;
  signal entreeRegMux               : natural range 0 to 2;

  -- UAL et indicateurs de comparaison Z (nul) et N (négatif).
  signal opUAL        : natural range 0 to n_detail - 1;
  signal vImmediate   : signed(RISC_GPIO_W - 1 downto 0);
  signal UALBMux      : std_logic;
  signal F_int, B_int : signed(RISC_GPIO_W - 1 downto 0);
  signal F            : signed(RISC_GPIO_W - 1 downto 0);
  signal Z, N         : std_logic;

  -- Unité de branchement.
  signal condBr : natural range 0 to n_detail - 1;
  signal valBr  : std_logic;

  -- Mémoire de données interne.
  signal MD       : memoireDonnees_t;
  signal chargeMD : std_logic;

  -- Compteur de programme et instruction décodée.
  signal CP          : unsigned(RISC_MEMI_W - 1 downto 0);
  signal instruction : instruction_t;
begin
  -- Lecture de l'instruction à l'adresse CP et décodage de ses champs.
  o_inst_addr  <= CP;
  instruction <= to_inst(i_inst);
  iCat        <= instruction.categorie;
  iDet        <= instruction.detail;
  iReg1       <= instruction.reg1;
  iReg2       <= instruction.reg2;
  iVal        <= instruction.valeur;

  -- CP relatif pour les branchements; attente d'une donnée valide sur GPIO.
  P_CP : process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        CP <= (others => '0');
      else
        if valBr = '1' then
          CP <= to_unsigned(to_integer(CP) + to_integer(iVal), CP'length);
        elsif iCat = memoire and iDet = lireGPIO_in then
          if i_GPIO_valide = '1' then
            CP <= CP + to_unsigned(1, CP'length);
          end if;
        else
          CP <= CP + to_unsigned(1, CP'length);
        end if;
      end if;
    end if;
  end process;

  -- Deux ports de lecture et un port d'écriture synchrone.
  A <= fichierRegistres(to_integer(choixA));
  B <= fichierRegistres(to_integer(choixB));

  -- Source d'écriture : 0 = UAL, 1 = mémoire de données, 2 = GPIO.
  entreeReg <=
    F when entreeRegMux = 0
    else MD(to_integer(unsigned(F(RISC_MEMD_W - 1 downto 0)))) when entreeRegMux = 1
    else i_GPIO;

  P_FR : process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        fichierRegistres <= (others => (others => '0'));
      else
        if chargeRegistre = '1' then
          fichierRegistres(to_integer(choixCharge)) <= entreeReg;
        end if;
      end if;
    end if;
  end process;

  -- Conditions de branchement calculées à partir de Z et N.
  with condBr select
    valBr <=
    Z                when egal,
    not(Z)           when diff,
    N                when ppq,
    not(N) and not(Z) when pgq,
    N or Z           when ppe,
    not(N)           when pge,
    '1'              when toujours,
    '0'              when jamais,
    '0'              when others;

  -- Écriture synchrone en mémoire à l'adresse calculée par l'UAL.
  P_MD : process(clk)
  begin
    if rising_edge(clk) then
      if chargeMD = '1' then
        MD(to_integer(unsigned(F(RISC_MEMD_W - 1 downto 0)))) <= B;
      end if;
    end if;
  end process;

  -- Second opérande : registre B ou valeur immédiate avec extension de signe.
  B_int <= B when UALBMux = '0' else vImmediate;
  F     <= F_int;

  -- La multiplication utilise les moitiés basses signées des opérandes.
  -- Adiv2 réalise un décalage arithmétique d'un bit vers la droite.
  with opUAL select
    F_int <=
    A                    when passeA,
    B_int                when passeB,
    A + B_int            when AplusB,
    A - B_int            when AmoinsB,
    A and B_int          when AetB,
    A or B_int           when AouB,
    not(A)               when nonA,
    A xor B_int          when AouxB,
    abs(A)               when absA,
    minimum(A, B_int)    when minAB,
    maximum(A, B_int)    when maxAB,
    (A(RISC_GPIO_W / 2 - 1 downto 0) *
     B_int(RISC_GPIO_W / 2 - 1 downto 0)) when AmultB,
    shift_right(A, 1)    when Adiv2,
    (others => '1')      when others;

  Z <= '1' when F_int = to_signed(0, RISC_GPIO_W) else '0';
  N <= F_int(F_int'left);

  -- Résultat GPIO enregistré; o_GPIO_valide est activé lors de son écriture.
  P_o_GPIO : process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        o_GPIO        <= (others => '0');
        o_GPIO_valide <= '0';
      else
        if iCat = memoire and iDet = ecrireGPIO_out then
          o_GPIO        <= B;
          o_GPIO_valide <= '1';
        else
          o_GPIO_valide <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Commandes du chemin de données à partir de la catégorie d'instruction.
  chargeRegistre <=
    '1' when (
      iCat = reg or
      iCat = reg_valeur or
      (iCat = memoire and iDet = lirememoire) or
      (iCat = memoire and iDet = lireGPIO_in and i_GPIO_valide = '1'))
    else '0';

  -- reg1 = destination, reg2 = premier opérande. En mode registre-registre,
  -- les bits bas de la valeur immédiate désignent le second opérande.
  choixCharge <= iReg1;
  choixA      <= iReg2;
  addrReg     <= unsigned(iVal(RISC_AREG_W - 1 downto 0));
  choixB      <= addrReg when iCat = reg else iReg1;

  vImmediate <= resize(iVal, vImmediate'length);
  UALBMux    <= '1' when iCat = reg_valeur or iCat = memoire
                else '0';

  -- Mémoire : adresse de base + déplacement. Branchement : comparaison A - B.
  opUAL <= AplusB when iCat = memoire else
           AmoinsB when iCat = branchement else
           iDet;

  condBr <= iDet when iCat = branchement else jamais;

  chargeMD <= '1' when iCat = memoire and iDet = ecrireMemoire else '0';

  entreeRegMux <= 1 when iCat = memoire and iDet = lireMemoire else
                  2 when iCat = memoire and iDet = lireGPIO_in else
                  0;

end RISCV;
