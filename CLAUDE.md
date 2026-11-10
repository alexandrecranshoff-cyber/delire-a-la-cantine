# Délire à la cantine

Jeu vidéo de stratégie tactique au tour par tour (genre UFO / Jagged Alliance), adapté d'un jeu de plateau. Moteur : **Godot 4.6**, GDScript.

## Cible et décisions de design

- Plateforme : navigateur (export web Godot, rendu Compatibilité / WebGL 2). Garder les assets légers.
- 3D, adaptation fidèle du plateau, jouée comme UFO : 12 points d'action par élève (1 PA par case, tir 4 PA une fois par tour), valeurs à régler.
- Dés visibles à l'écran, brouillard de guerre et ligne de vue.
- Modes : solo (campagne « année scolaire » avec expérience) et tour de rôle sur le même écran.
- Style BD franco-belge original, années 80, bulles de BD. Noms d'origine conservés.
- Game design complet : https://claude.ai/artifact/QPW5UDhbJLqegseVnz4nmJ

## Langue

Communication, documentation et messages de commit en français. Code (noms de variables, fonctions, classes) en anglais, commentaires en français.

## Structure

- `docs/regles-originales.md` : règles du jeu de plateau, référence du moteur de règles.
- `data/` : valeurs chiffrées (personnages, projectiles) en JSON. Ne jamais dupliquer ces chiffres en dur dans le code.
- `scripts/rules/` : moteur de règles pur (aucune dépendance aux nœuds de scène), entièrement testable.
- `scripts/ai/` : comportement des pions automatiques (profs, cuisinier, neutres, berserk, adversaires IA).
- `scripts/ui/` et `scenes/` : affichage, caméra, interface.
- `assets/` : modèles (glTF/GLB), sprites, textures, audio. Fichiers lourds suivis par Git LFS.
- `tests/` : tests automatiques des règles.

## Principes

- Séparer strictement règles et affichage : l'état de partie est une donnée, les scènes l'affichent.
- Tout tirage aléatoire passe par un générateur de dés à graine, pour rejouer et tester une partie.
- Chaque règle du livret implémentée doit avoir un test, en reprenant si possible l'exemple du livret.
- Ne pas recréer un jeu existant : s'inspirer du genre et des mécaniques seulement. Les noms et textes d'origine du livret sont provisoires, les droits restant à vérifier avant diffusion.

## Assets

Pipeline prévu : Higgsfield (images, fiches perso, 3D, audio) → retouche Blender → export glTF → import Godot. Nommer les fichiers en `snake_case` sans accents.
