class_name Unit
extends RefCounted
## Un pion : élève, prof, cuisinier, neutre ou chariot. Pure donnée.

enum Kind { STUDENT, TEACHER, COOK, NEUTRAL, CART }
enum Status {
	ACTIVE,     ## en jeu, contrôlé normalement
	SATURATED,  ## moral à 0 : file vers la sortie
	CAPTURED,   ## tenu par un prof (sous son pion)
	FLEEING,    ## neutre en fuite
	BERSERK,    ## neutre devenu fou furieux
	OUT,        ## hors du terrain
}

const NO_TEAM := -1

var id := 0
var kind: Kind = Kind.STUDENT
var name := ""
var team := NO_TEAM
var pos := Vector2i.ZERO
var status: Status = Status.ACTIVE

var moral := 0
var max_moral := 0
var dex_d6 := 0
var dex_bonus := 0

var ap := 0
var ap_bonus := 0           ## PA gagnés en campagne (année scolaire)
var has_shot := false        ## a déjà tiré (ou ne peut plus tirer) ce tour
var on_table := false
var turns_on_table := 0
var loaded := false          ## garde une munition après avoir quitté sa source
var rallied := false         ## neutre passé dans un camp (ne compte pas pour la victoire)
var captor_id := -1
var captive_ids: Array[int] = []


func is_on_board() -> bool:
	return status != Status.OUT


## Peut agir sous le contrôle de son camp.
func is_controllable() -> bool:
	return status == Status.ACTIVE and team != NO_TEAM


func kind_key() -> String:
	match kind:
		Kind.STUDENT: return "eleve"
		Kind.TEACHER: return "prof"
		Kind.COOK: return "cuisinier"
		Kind.NEUTRAL: return "neutre"
		_: return "chariot"
