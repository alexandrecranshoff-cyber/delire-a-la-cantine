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
