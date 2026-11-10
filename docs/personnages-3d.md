# Personnages 3D : de la fiche au pion animé

Les onze personnages (six élèves, prof, cuisinier, trois neutres) sont des modèles 3D avec squelette,
affichés façon BD (deux tons et contour à l'encre). Ce document décrit la chaîne qui les produit, pour
pouvoir en refaire un ou en ajouter.

## Chaîne de fabrication

1. **Trois vues en pose A** (Higgsfield, Nano Banana 2.1, 1024 px, fond uni) à partir de la fiche du
   personnage : face, profil gauche, dos. Les bras sont écartés du corps d'environ 30° sur les trois
   vues, sinon le modèle a les bras soudés au torse. Si le profil sort tourné vers la droite, on le
   fait retourner avec la consigne « Mirror this image horizontally ».
2. **Modèle 3D** (Higgsfield, `tripo_h3_1_multiview_to_3d`, vues dans l'ordre face, gauche, dos,
   12 000 faces, texture détaillée, sans PBR). Le modèle sort haut de 1 unité et **regarde vers +X**.
3. **Quart de tour** : `python3 tools/tourner_glb.py modele.glb modele_face.glb`. Le personnage
   regarde alors vers +Z. Cette étape est indispensable (voir plus bas).
4. **Squelette** (Higgsfield, `meshy_rigging`, `height_meters` = taille du personnage). Le résultat a
   24 os aux noms fixes (Hips, Spine, LeftArm, RightUpLeg…).
5. **Allègement** : `python3 tools/alleger_glb.py rig.glb assets/hd/personnages/<nom>.glb --taille 1024
   --sans-animation`, et `--taille 512` vers `assets/sd/personnages/`. Environ 0,9 Mo par personnage
   en HD et 0,7 Mo en SD.

Le nom du fichier est celui du champ `image` de `data/apparence.json`. S'il manque, le jeu retombe
sur le pion en carton à cinq vues (argument `carton` pour le forcer).

## Animations partagées

Quatre gestes sont joués par Grobill dans la bibliothèque Meshy (`enable_animation` et
`animation_action_id`) : repos (0), marche (30), lancer (421), touché (178). Les fichiers, texture
réduite à 64 px, sont dans `assets/reference/animations/grobill_<clip>.glb`.

`godot --headless --path . -s tools/extraire_animations.gd` en tire `assets/animations/<clip>.res` :
pour chaque os et chaque image, la rotation depuis la pose de liaison, exprimée dans le repère du
squelette. Au chargement, `GameAssets.animations_for` réapplique ces rotations à la pose de liaison
de chaque personnage. Tous les squelettes ayant les mêmes noms d'os, un seul jeu de quatre clips sert
aux onze personnages, quelles que soient leur taille et leur corpulence.

## Pièges rencontrés

- **Orientation** : Meshy suppose un personnage qui regarde vers +Z. Avec un modèle Tripo laissé tel
  quel (+X), le squelette est faux sans aucun message d'erreur : jambes écartées d'avant en arrière,
  os des bras dans le torse, animations qui tordent les pieds. Les paramètres d'orientation de Tripo
  n'y changent rien. On vérifie un squelette en regardant la position des os : les jambes doivent
  être séparées selon X et les orteils pointer vers +Z.
- **Envoi du modèle tourné** : `meshy_rigging` prend une adresse publique. Le modèle tourné est
  envoyé avec `media_upload` (fichier `.glb`), un `curl -X PUT` vers l'adresse présignée puis
  `media_confirm` (type `file`) ; on passe ensuite à Meshy l'adresse `url` rendue par `media_upload`.
- **Vues incohérentes** : si la face a les bras le long du corps et le dos les bras écartés, Tripo
  fabrique des bras doubles. Refaire la vue fautive avant de lancer le modèle.
- Chaque passage de squelette donne des os légèrement différents : les clips de référence et le
  modèle de Grobill viennent chacun de leur propre fichier, ce que le reciblage absorbe.

## Coûts constatés (crédits Higgsfield)

Vue : 2. Modèle Tripo : 9 à 12. Squelette : 5, ou 8 avec une animation. Soit environ 25 crédits par
personnage, et 32 pour les quatre clips de référence.
