# Délire à la cantine

Jeu vidéo de stratégie tactique au tour par tour (genre UFO / Jagged Alliance), adapté d'un jeu de plateau. Moteur : **Godot 4.6**, GDScript.

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
