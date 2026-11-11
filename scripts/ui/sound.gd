class_name Sound
extends Node
## Musique et bruitages. Un seul exemplaire, créé par la scène principale.

static var instance: Sound

var _music := AudioStreamPlayer.new()
var _ambience := AudioStreamPlayer.new()
var _pool: Array[AudioStreamPlayer] = []
var _current_music := ""


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music.volume_db = -12.0
	add_child(_music)
	_ambience.volume_db = -22.0
	add_child(_ambience)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)


static func play(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if instance != null:
		instance._play(name, volume_db, pitch)


static func music(name: String) -> void:
	if instance != null:
		instance._set_music(name)


static func ambience(on: bool) -> void:
	if instance != null:
		instance._set_ambience(on)


static func refresh_settings() -> void:
	if instance != null:
		instance._apply_music_setting()
		instance._ambience.stream_paused = not GameConfig.sound_on


## Musique coupée : on l'arrête pour de bon (une pause posée juste après play() ne tient pas
## toujours, en particulier dans le navigateur) ; rallumée : on la reprend.
func _apply_music_setting() -> void:
	if not GameConfig.music_on:
		_music.stop()
	elif _music.stream != null and not _music.playing:
		_music.stream_paused = false
		_music.play()


func _play(name: String, volume_db: float, pitch: float) -> void:
	if not GameConfig.sound_on:
		return
	var stream := GameAssets.sound(name)
	if stream == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch * randf_range(0.94, 1.06)
			p.play()
			return


func _set_music(name: String) -> void:
	if name == _current_music:
		return
	_current_music = name
	var stream := GameAssets.music(name) if name != "" else null
	_music.stop()
	_music.stream = stream
	if stream != null and GameConfig.music_on:
		_music.play()


func _set_ambience(on: bool) -> void:
	if on and not _ambience.playing:
		var s := GameAssets.sound("brouhaha")
		if s is AudioStreamWAV:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_end = int(s.get_length() * s.mix_rate)
		_ambience.stream = s
		_ambience.play()
		_ambience.stream_paused = not GameConfig.sound_on
	elif not on:
		_ambience.stop()
