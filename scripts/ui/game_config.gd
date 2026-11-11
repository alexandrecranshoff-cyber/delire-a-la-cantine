class_name GameConfig
extends RefCounted
## Choix du menu pour la partie à lancer.

static var solo := true
static var difficulty := "normal"
static var seed_value := 0
static var players := 2
static var music_on := true
static var sound_on := true
static var fast := false
## Sauvegarde à reprendre au prochain lancement de partie (vide : nouvelle partie).
static var pending_load := {}
## Niveau joué (partie libre) : data/niveaux/*.json.
static var level_path := "res://data/niveaux/niveau_1.json"
## Partie lancée depuis l'année scolaire (le service du mois en cours).
static var campaign := false
## Fin du dernier service joué, pour l'écran de l'année : {"gagne", "eleves": nom -> {"xp", "colle"}}.
static var last_gains := {}
## Ouvrir le bulletin en arrivant sur l'écran de l'année (trimestre terminé).
static var show_bulletin := false
