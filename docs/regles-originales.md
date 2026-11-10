# Règles du prototype (jeu de plateau)

Transcription structurée du livret « Délire à la cantine » (encart de magazine, Didier Guiserix et François Marcela-Froideval). Sert de référence pour le moteur de règles. Les adaptations au jeu vidéo sont décidées dans le document de game design, pas ici.

Les valeurs chiffrées sont aussi dans `data/personnages.json` et `data/projectiles.json`.

## Matériel et but

- 2 à 4 joueurs. Plateau : une salle (8 tables numérotées, 6 portes, 2 robinets) et une cuisine (3 bacs, 2 chariots).
- 4 équipes de 6 élèves nommés, 24 neutres, 10 profs, 1 cuisinier, 2 chariots.
- Victoire : être le dernier joueur à avoir au moins un élève sur le terrain. Les neutres ralliés ne comptent pas.

## Mise en place

- Cuisinier sur la case C, chariots sur leurs cases. Profs hors du plateau au départ.
- Max 3 élèves d'une même équipe autour d'une table.
- 4 joueurs : 2 groupes de 3 par joueur. A : tables 1 et 4 ; B : 5 et 8 ; C : 2 et 3 ; D : 6 et 7.
- 3 joueurs : A : 1 et 3 ; B : 5 et 7 ; C : 2 et 6.
- 2 joueurs : une équipe chacun (A : 1 et 6, B : 2 et 5) ou deux équipes chacun (A : 1, 2, 3, 4 ; B : 5, 6, 7, 8).
- Élèves des équipes non attribuées = neutres. Neutres sur les cases N.

## Tour d'un joueur

1. Déplacement des élèves de son équipe.
2. Tir de chacun de ses élèves, décompte immédiat du moral.
3. Mouvements et tirs des pions « automatiques » (profs, cuisinier, neutres, saturés), joués par le joueur **précédent**.

Tours 1 à 4 : les tables sont couvertes de munitions. À partir du tour 5, les neutres quittent leur place et sortent par la porte la plus proche ; les élèves doivent trouver d'autres munitions (bacs et chariots). Un élève peut encore tirer une fois après avoir quitté la table.

## Déplacement

- Potentiel par tour : élève 8, prof 4, cuisinier 3, neutre 3, chariot poussé 3.
- 8 directions (orthogonales et diagonales), changements de direction libres.
- On ne passe jamais par-dessus un pion, et on ne se faufile pas entre deux tables en diagonale.
- Monter sur une table depuis une case au contact : coûte le tour entier, pas de tir ce tour-là.
- Sur la table : déplacement libre. Descendre : un tour complet vers une case sol au contact. Max 2 tours sur une table.
- Seul chevauchement : l'élève capturé est placé sous le prof.

## Tir

1. Le joueur annonce le tireur et la cible.
2. Distance = nombre de cases entre tireur et cible (compté comme un déplacement). La trajectoire « réelle » (ligne droite) ne doit pas traverser un mur.
3. 2D6 sur la table des projectiles : donne le projectile, ses dégâts et son CX.
4. Seuil = distance + CX.
5. Jet de dextérité du tireur. Si résultat ≥ seuil : touché, on jette les dégâts et on les retire du moral. Sinon : tir raté.
6. Moral à 0 : « saturation », l'élève sort par la porte la plus proche (déplacement automatique).

Exemple du livret : Grobill tire à 9 cases, 2D6 = 8 (tripes, CX 3), seuil 12. Dextérité 3D = 14, touché. Dégâts 4D = 18 points de moral.

### Trajectoire

- Si tireur et cible sont alignés (ligne, colonne ou diagonale) : ligne directe.
- Sinon : progression en diagonale jusqu'à la ligne ou la colonne de la cible, puis progression droite le long de celle-ci.

### Tir raté

La nourriture tombe sur la case de chute et peut toucher, par priorité :
1. le pion sur la case de chute ;
2. un pion au contact de la case de chute, sur la trajectoire ;
3. un pion au contact de la case de chute, hors trajectoire, dans l'ordre de la figure 1 du livret (b, 1, 2, 3, 4, 5, 6).

La cible elle-même ne peut pas être touchée par un tir raté.

### Neutre touché

Jet d'1D6 :
- 1 : il rejoint le camp du tireur jusqu'à la fin de la partie (ou jusqu'à saturation), sans compter pour la victoire.
- 2 à 5 : il fuit vers la sortie par le chemin le plus court (même en grimpant sur une table).
- 6 : il devient « berserk », tire sur n'importe qui, joué automatiquement à la fin de chaque tour par chaque joueur à tour de rôle. Il ramasse ses munitions au sol et tire donc à chaque tour.

## Profs

- Entrent dès la fin du tour du premier joueur, joués par le dernier joueur du tour. 1D6 = numéro de la porte d'entrée. Un prof par tour de joueur.
- Le joueur qui a lancé le dé dirige le prof vers l'élève actif (non neutre) le plus proche, même s'il est sur une table (le prof n'y monte pas).
- Capture : au contact (une des 8 cases voisines), 1D6 : 1 à 4 réussi. Au tour suivant, le prof emmène sa victime à vitesse max vers la sortie la plus proche. Pour le stopper, il faut le saturer (même procédure que pour un élève) ; il relâche alors sa victime.
- Double prise : au contact de deux élèves, annonce puis 1D6 : 1 ou 2, il emmène les deux. Échec : aucun n'est pris.

## Cuisinier

- Entre en action dès qu'un élève franchit le seuil de la cuisine. Joué automatiquement par le joueur précédent.
- Peut tirer comme un élève s'il a des projectiles sous la main.
- Plongeon : au contact de l'élève et à une ou deux cases d'un bac ou d'un chariot, 1D6 : 1 à 4, l'élève est plongé dans le « plat du jour » et retiré du jeu.

## Projeter un ennemi dans un bac ou un chariot

Conditions : être au contact de la victime, la victime au contact ou à une case du bac ou du chariot, et assez d'élèves d'une même équipe au contact :
- 3 élèves pour un élève adverse ;
- 5 élèves pour un prof ;
- 7 élèves pour le cuisinier.

Puis 1D6 : 1 à 4, réussi.

## Chariots, bacs, robinets

- Chariots (purée, tripes) et bacs : réserve inépuisable de munitions (sauf le bac à vaisselle, qui ne fournit rien mais où l'on peut être projeté).
- Bacs immobiles. Un élève au contact peut pousser un chariot de 3 cases max, sans tirer ce tour-là ; les autres élèves ou le cuisinier au contact du chariot après son déplacement peuvent tirer normalement.
- Robinets : un personnage au contact peut tirer en « arrosant » (portée 5 cases, CX 0, dégâts 1D).

## Déplacements automatiques

Effectués à la fin de chaque tour par le joueur précédent, au maximum du potentiel de chaque pion :
- élève saturé : rejoindre au plus vite la sortie la plus proche ;
- prof : saisir l'élève le plus proche ;
- neutre en fuite : sortie la plus proche.

En cas d'égalité ou d'obstacle, le joueur qui manipule le pion décide.
