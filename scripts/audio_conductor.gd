extends Node
class_name AudioConductor

signal beat_reached(beat_index: int, song_position: float)

const BeatChartScript = preload("res://scripts/beat_chart.gd")
const MUSIC_STREAM = preload("res://assets/audio/music_dash_prototype.wav")
const DEFAULT_BPM := 120.0

@export var bpm := DEFAULT_BPM
@export var audio_offset_seconds := 0.0

var _player: AudioStreamPlayer
var _beat_chart: RefCounted
var _paused_position := 0.0
var _song_paused := false

func _ready() -> void:
	_beat_chart = BeatChartScript.new()
	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"
	_player.bus = "Master"
	_player.stream = MUSIC_STREAM
	add_child(_player)

func song_position() -> float:
	if _player == null or not _player.playing or _player.stream_paused:
		return _paused_position
	var estimated_position := _player.get_playback_position()
	estimated_position += AudioServer.get_time_since_last_mix()
	estimated_position -= AudioServer.get_output_latency()
	return maxf(0.0, estimated_position)

func consume_beats_until(position: float) -> Array[int]:
	var beats: Array[int] = _beat_chart.drain_beats_until(position, bpm, audio_offset_seconds)
	for beat_index in beats:
		beat_reached.emit(beat_index, _beat_chart.beat_time(beat_index, bpm, audio_offset_seconds))
	return beats

func start_from(position: float = 0.0) -> void:
	if _player == null:
		return
	_paused_position = maxf(0.0, position)
	_song_paused = false
	_beat_chart.reset()
	_beat_chart.seek(_paused_position, bpm, audio_offset_seconds)
	if _player.stream == null:
		_player.stream = MUSIC_STREAM
	_player.stream_paused = false
	_player.play(_paused_position)

func pause_song() -> void:
	if _player == null or not _player.playing:
		return
	_paused_position = song_position()
	_player.stream_paused = true
	_song_paused = true

func resume_song() -> void:
	if _player == null or not _song_paused:
		return
	_player.stream_paused = false
	_song_paused = false

func stop_song() -> void:
	if _player == null:
		return
	_paused_position = 0.0
	_song_paused = false
	_player.stop()
	_player.stream_paused = false
	_player.stream = null
	_beat_chart.reset()

func is_song_playing() -> bool:
	return _player != null and _player.playing and not _player.stream_paused
