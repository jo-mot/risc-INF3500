# Bancs d'essai et simulation

Les bancs d'essai sont séparés des descriptions matérielles. Chaque banc possède
une entité distincte pour pouvoir être compilé dans la même bibliothèque `work`.

## Bancs disponibles

| Fichier | Entité à simuler | Stimuli et observation |
| --- | --- | --- |
| [`core/risc_sqrt_tb.vhd`](core/risc_sqrt_tb.vhd) | `RISC_sqrt_tb` | Programme de dichotomie; assertion comparant le résultat à `floor(sqrt(entrée))`, avec une tolérance de 1 |
| [`core/risc_factorial_tb.vhd`](core/risc_factorial_tb.vhd) | `RISC_factorial_tb` | Programme de factorielle; export des résultats, sans assertion de référence |
| [`memory/instruction_memory_tb.vhd`](memory/instruction_memory_tb.vhd) | `instruction_memory_tb` | Dix écritures puis dix lectures; observation des signaux |
| [`interfaces/axis2rom_tb.vhd`](interfaces/axis2rom_tb.vhd) | `AXIS2ROM_tb` | Flux de données avec interruption de `valid`; observation des signaux |
| [`interfaces/axis2rom_memory_tb.vhd`](interfaces/axis2rom_memory_tb.vhd) | `AXIS2ROM_memory_tb` | Chargement de la mémoire, puis lecture; observation des signaux |

Les programmes du processeur sont les constantes `memoire_inst` des deux premiers
bancs. Ils sont écrits avec `gen_inst`, puis convertis en mots binaires par
`inst_to_unsigned`.

## Ordre de compilation

Utiliser le mode **VHDL-2008** du simulateur.

1. `rtl/core/risc_utils_pkg.vhd`
2. `rtl/core/risc.vhd`
3. `rtl/memory/instruction_memory.vhd`
4. `rtl/interfaces/axis2rom.vhd`
5. Les fichiers de `sim/core`, `sim/memory` et `sim/interfaces`

Les fichiers de `rtl/platform` ne sont pas nécessaires à ces simulations.
La compilation de `top.vhd` exige notamment le `zynq_wrapper` externe.

### Exemple avec GHDL dans PowerShell

Depuis la racine du dépôt, avec GHDL installé et accessible dans le `PATH` :

```powershell
New-Item -ItemType Directory -Force build | Out-Null
$vhdlSources = @(
    'rtl/core/risc_utils_pkg.vhd'
    'rtl/core/risc.vhd'
    'rtl/memory/instruction_memory.vhd'
    'rtl/interfaces/axis2rom.vhd'
    'sim/core/risc_sqrt_tb.vhd'
    'sim/core/risc_factorial_tb.vhd'
    'sim/memory/instruction_memory_tb.vhd'
    'sim/interfaces/axis2rom_tb.vhd'
    'sim/interfaces/axis2rom_memory_tb.vhd'
)
ghdl -a --std=08 --workdir=build @vhdlSources
ghdl -e --std=08 --workdir=build instruction_memory_tb
ghdl -r --std=08 --workdir=build instruction_memory_tb --vcd=build/instruction_memory.vcd
```

Ce premier exemple utilise les stimuli internes du banc mémoire et ne nécessite
aucun fichier de vecteurs.

## Entrées et sorties des tests du processeur

Les deux bancs du cœur ouvrent les mêmes noms de fichiers, conservés du projet
d'origine :

- `dichotomie_vecs.txt` : entrées entières, une par ligne.
- `dichotomie_out.txt` : résultats, un par ligne, créé ou remplacé par la simulation.

Ces chemins sont relatifs au **répertoire de lancement du simulateur**. Le fichier
d'entrée n'est pas inclus dans le dépôt. Il faut fournir les vecteurs du projet
pour reproduire les essais du processeur. Utiliser des entrées non négatives pour
le banc de racine carrée.

Une fois le fichier d'entrée placé à la racine, le banc de dichotomie se lance ainsi :

```powershell
ghdl -e --std=08 --workdir=build RISC_sqrt_tb
ghdl -r --std=08 --workdir=build RISC_sqrt_tb --vcd=build/risc_sqrt.vcd
```

Pour la factorielle, sélectionner `RISC_factorial_tb`. Exécuter les deux bancs
séparément et conserver la première sortie avant de lancer le second, car ils
écrivent dans le même fichier. La multiplication de l'UAL utilise des opérandes
signés de 16 bits dans cette configuration; les résultats ne sont donc pas ceux
d'une factorielle de précision arbitraire.

## Fin de simulation

Les bancs d'origine s'arrêtent avec `report "Fin" severity failure` pour le cœur,
ou `report "Done" severity failure` pour la mémoire et les interfaces. Le simulateur
peut donc retourner un code d'échec même à la fin normale du scénario.

Pour le banc de dichotomie, un message `Erreur racine` indique l'échec de l'assertion.
Les autres bancs n'ont pas d'assertion de référence : leur arrivée au message final
ne constitue pas à elle seule une validation fonctionnelle.
