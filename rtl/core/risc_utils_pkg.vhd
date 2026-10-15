-- Paramètres, format des instructions et fonctions d'encodage du RISC.

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.MATH_REAL.ceil;
use IEEE.MATH_REAL.log2;

package RISC_utils is
  -- gen_inst accepte 16 indices de registres. Le banc matériel est
  -- dimensionné par RISC_AREG_W : 5 bits d'adresse, soit 32 entrées.
  constant RISC_NREG   : positive := 16;
  constant RISC_AREG_W : positive := 5;
  -- Largeurs du chemin de données et des adresses mémoire.
  constant RISC_GPIO_W : positive := 32;
  constant RISC_MEMI_W : positive := 8;
  constant RISC_MEMD_W : positive := 8;
  -- Quatre catégories; le champ détail occupe quatre bits.
  constant n_instr         : natural  := 4;
  constant n_detail        : natural  := 16;

  -- Format à 32 bits : catégorie[31:30], détail[29:26],
  -- reg1[25:21], reg2[20:16], valeur immédiate signée[15:0].
  constant INST_START    : integer := RISC_GPIO_W - 1;
  constant INST_CAT_OFF  : integer := INST_START;
  constant INST_CAT_W    : integer := 2;
  constant INST_DET_OFF  : integer := INST_CAT_OFF - INST_CAT_W;
  constant INST_DET_W    : integer := 4;
  constant INST_REG1_OFF : integer := INST_DET_OFF - INST_DET_W;
  constant INST_REG_W    : integer := RISC_AREG_W;
  constant INST_REG2_OFF : integer := INST_REG1_OFF - INST_REG_W;
  constant INST_VAL_OFF  : integer := INST_REG2_OFF - INST_REG_W;
  constant INST_VAL_W    : integer := INST_VAL_OFF + 1;

  -- Représentation décodée et types de stockage.
  type instruction_t is record
    categorie : natural range 0 to n_instr - 1;
    detail    : natural range 0 to n_detail - 1;
    reg1      : unsigned(RISC_AREG_W - 1 downto 0);
    reg2      : unsigned(RISC_AREG_W - 1 downto 0);
    valeur    : signed(INST_VAL_W - 1 downto 0);
  end record;

  type fichierRegistres_t is
    array(0 to 2 ** RISC_AREG_W - 1) of signed(RISC_GPIO_W - 1 downto 0);
  type memoireDonnees_t is
    array(0 to 2 ** RISC_MEMD_W - 1) of signed(RISC_GPIO_W - 1 downto 0);

  -- Construction et conversion des instructions pour les programmes simulés.
  function gen_inst(
    cat  : natural range 0 to n_instr - 1;
    det  : natural range 0 to n_detail - 1;
    reg1 : integer range 0 to RISC_NREG - 1;
    reg2 : integer range 0 to RISC_NREG - 1;
    val  : integer range - 2 ** RISC_NREG to 2 ** RISC_NREG - 1
    ) return instruction_t;
  function to_inst(bits : unsigned(RISC_GPIO_W - 1 downto 0))
    return instruction_t;
  function inst_to_unsigned(inst : instruction_t)
    return unsigned;

  -- Catégories d'instructions.
  constant reg         : natural := 0;
  constant reg_valeur  : natural := 1;
  constant branchement : natural := 2;
  constant memoire     : natural := 3;

  -- Accès à la mémoire de données et aux GPIO.
  constant lireMemoire    : natural := 0;
  constant ecrireMemoire  : natural := 1;
  constant lireGPIO_in    : natural := 2;
  constant ecrireGPIO_out : natural := 3;

  -- Opérations de l'UAL.
  constant passeA  : natural := 0;
  constant passeB  : natural := 1;
  constant AplusB  : natural := 2;
  constant AmoinsB : natural := 3;
  constant AetB    : natural := 4;
  constant AouB    : natural := 5;
  constant nonA    : natural := 6;
  constant AouxB   : natural := 7;
  constant absA    : natural := 8;
  constant minAB   : natural := 9;
  constant maxAB   : natural := 10;
  constant AmultB : natural := 11;
  constant Adiv2   : natural := 12;

  -- Conditions de branchement.
  constant egal     : natural := 0;
  constant diff     : natural := 1;
  constant ppq      : natural := 2;
  constant pgq      : natural := 3;
  constant ppe      : natural := 4;
  constant pge      : natural := 5;
  constant toujours : natural := 6;
  constant jamais   : natural := 7;

  -- NOP : branchement jamais pris. STOP : branchement sur l'instruction courante.
  constant NOP  : instruction_t;
  constant STOP : instruction_t;
end package;

package body RISC_utils is
  function gen_inst(
    cat  : natural range 0 to n_instr - 1;
    det  : natural range 0 to n_detail - 1;
    reg1 : integer range 0 to RISC_NREG - 1;
    reg2 : integer range 0 to RISC_NREG - 1;
    val  : integer range - 2 ** RISC_NREG to 2 ** RISC_NREG - 1
    ) return instruction_t
  is
    variable ret : instruction_t;
  begin
    ret := (
      cat,
      det,
      to_unsigned(reg1, INST_REG_W),
      to_unsigned(reg2, INST_REG_W),
      to_signed(val, INST_VAL_W)
      );
    return ret;
  end gen_inst;
  function to_inst(bits : unsigned(RISC_GPIO_W - 1 downto 0))
    return instruction_t
  is
    variable ret : instruction_t;
  begin
    ret := (
      to_integer(bits(INST_CAT_OFF downto INST_CAT_OFF - INST_CAT_W + 1)),
      to_integer(bits(INST_DET_OFF downto INST_DET_OFF - INST_DET_W + 1)),
      bits(INST_REG1_OFF downto INST_REG1_OFF - INST_REG_W + 1),
      bits(INST_REG2_OFF downto INST_REG2_OFF - INST_REG_W + 1),
      signed(bits(INST_VAL_OFF downto 0))
      );
    return ret;
  end to_inst;
  function inst_to_unsigned(inst : instruction_t)
    return unsigned
  is
    variable ret : unsigned(RISC_GPIO_W - 1 downto 0);
  begin
    ret := to_unsigned(inst.categorie, INST_CAT_W) &
           to_unsigned(inst.detail, INST_DET_W) &
           inst.reg1 &
           inst.reg2 &
           unsigned(inst.valeur);
    return ret;
  end inst_to_unsigned;

  constant NOP : instruction_t := gen_inst(
    branchement, jamais, 0, 0, 0
    );
  constant STOP : instruction_t := gen_inst(
    branchement, toujours, 0, 0, 0
    );
end package body;
