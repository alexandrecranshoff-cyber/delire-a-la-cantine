# Interprétations des règles

Points où le livret laisse un doute, et le choix fait dans le moteur (`scripts/rules/`). Chaque choix est couvert par un test.

| Sujet | Choix | Source |
| --- | --- | --- |
| Distance | Nombre de cases en 8 directions (la diagonale compte 1). | « compté comme un déplacement » ; figure 2 |
| Trajectoire non alignée | Diagonale jusqu'à la rangée ou la colonne de la cible, puis tout droit. | Figure 2 (testée case par case) |
| Mur | La droite entre les centres des cases ne doit traverser aucun mur. Les tables n'arrêtent pas les tirs. | Paragraphe « tir » |
| Tir raté | La nourriture tombe sur la case juste avant la cible (« a »). Ordre : a, b (case précédente sur la trajectoire), puis 1 à 6 autour de a : derrière, sur les côtés, devant, gauche avant droite. | Figure 1 (les deux exemples sont testés) |
| Tir raté et tireur | Le tireur ne peut pas être touché par sa propre retombée. | Choix, le livret ne dit rien |
| Pion touché par une retombée | Il subit les dégâts du projectile sans nouveau jet de dextérité. | « le projectile atteindra » |
| Diagonale entre obstacles | Interdite si les deux cases de côté sont des obstacles (table, mur, bac). Un pion n'est pas un obstacle de ce type. | « on ne se faufile pas entre deux tables » |
| Munitions | Au contact d'une table (tours 1 à 4), d'un bac (sauf vaisselle) ou d'un chariot. Un élève qui s'éloigne garde une munition pour un tir. | « déroulement de la partie » |
| Monter, descendre d'une table | Il faut avoir encore tous ses PA ; l'action les consomme et interdit le tir. | Game design (12 PA) |
| Victoire | Comptent les élèves actifs ou capturés (un capturé peut être libéré). Saturés, plongés et neutres ralliés ne comptent pas. | « but du jeu » |
| Projection | Victime au contact ou à une case d'un bac ou d'un chariot (distance 2 au plus). Neutre : comme un élève (3). | Paragraphe « projeter » |
| Plan du niveau 1 | Relevé sur les 4 morceaux du plateau (pages 4 à 7) : salle de 30 × 27 cases, 8 tables de 10 × 3, cuisine de 7 rangées, 2 ouvertures de 5 cases, portes 1 à 6 de 2 cases. Chaque table a 8 places, 24 cases N. Les chariots occupent une seule case. | `tools/generer_niveau_1.py` |
| Élèves des tables libres | À 2 ou 3 joueurs, ils deviennent des neutres, assis à leurs tables. | « mise en place » |

## Adaptations pour le jeu vidéo

Choix faits pour la version jouable du niveau 1. Les valeurs sont dans `data/regles_video.json` et `data/difficulte.json`, et chaque choix est couvert par un test (`tests/test_auto_pawns.gd`, `tests/test_turn_flow.gd`, `tests/test_game_setup.gd`).

| Sujet | Choix | Pourquoi |
| --- | --- | --- |
| Profs et cuisinier | Ils agissent une fois par manche, après la dernière bande (`adultes_par_manche: 1`). Le livret les fait agir après chaque joueur (`0`). | En parties simulées avec la règle du livret, 9 élèves sur 12 étaient emmenés sans pouvoir réagir et le niveau de l'adversaire ne changeait rien au résultat. Avec un tour pour réagir, se placer compte. |
| Entrée des profs | Un prof entre tous les `prof_periode` tours de bande (livret : 1). Réglé par la difficulté : 3, 2 ou 1. | Dosage de la pression. |
| Cible d'un prof | L'élève actif le plus proche en pas de marche, neutres ralliés compris. Il ne tente que la prise simple. | « l'élève actif (non neutre) le plus proche » ; la double prise reste disponible dans le moteur. |
| Cuisinier | Il ne quitte pas la cuisine. Réveillé, il plonge l'élève au contact près d'un bac, sinon il tire s'il a des munitions sous la main. | Le livret ne dit pas s'il sort. |
| Sonnerie | À la fin du tour 12 (`tours_max`), la bande qui a fait perdre le plus de moral aux élèves des autres bandes (le « chahut ») gagne, puis celle qui garde le plus de moral, puis celle qui a le plus d'élèves ; égalité possible. Toucher un neutre ou un élève rallié ne compte pas. | Borne la partie à 30 à 60 minutes, et une bande qui se cache sans tirer ne peut plus gagner à la sonnerie (relevé par l'essai de jeu). |
| Neutre rallié | 7 PA par tour (`pa_neutre_rallie`) : 3 cases et un tir. | Potentiel 3 du livret, traduit en PA. |
| Neutres au tour 5 | Les neutres encore à table partent vers la porte la plus proche, 3 cases par tour de bande. | « déroulement de la partie » |
| Berserk | À chaque tour de bande, il tire sur le pion visible le plus proche, quel qu'il soit, puis s'en rapproche. | « tire sur n'importe qui » |
| Brouillard | Une bande voit ce que voient ses élèves ; seuls les murs cachent, comme ils arrêtent les tirs. | Game design. |
| Tir hors de portée | On ne peut pas viser une cible plus loin que le plus haut total des dés d'adresse du tireur (distance + plus petite CX), ni un élève saturé. | Évite des tirs perdus d'avance ; relevé par l'essai de jeu. |
| Difficulté du solo | Trois niveaux : fréquence des profs, moral de départ et finesse de l'adversaire. Aucun dé truqué. | Demande du 10 novembre 2026. |
| Cases rouges | Les cases à portée d'un prof libre ou du cuisinier (son déplacement plus le contact) sont signalées. | Lisibilité : le joueur voit le risque avant de s'engager. |

