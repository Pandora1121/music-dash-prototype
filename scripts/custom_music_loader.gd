extends RefCounted
class_name CustomMusicLoader

const MusicAnalyzerScript = preload("res://scripts/music_analyzer.gd")

var _analyzer: RefCounted

func _init(analyzer: RefCounted = null) -> void:
	_analyzer = analyzer if analyzer != null else MusicAnalyzerScript.new()

func load_file(path: String) -> Dictionary:
	if path.is_empty():
		return _failure("No WAV file was selected.")
	if path.get_extension().to_lower() != "wav":
		return _failure("Choose a WAV audio file.")
	if not FileAccess.file_exists(path):
		return _failure("The selected WAV file could not be found or opened.")
	var stream := AudioStreamWAV.load_from_file(path)
	if stream == null:
		return _failure("The selected file is not a readable WAV audio file.")
	var analysis: Dictionary = _analyzer.analyze(stream)
	if analysis.get("status", &"failed") != &"ok":
		return _failure(String(analysis.get("reason", "The WAV file could not be analyzed.")))
	return {
		"status": &"ok",
		"reason": "",
		"stream": stream,
		"analysis": analysis,
		"path": path,
		"display_name": path.get_file(),
	}

func _failure(reason: String) -> Dictionary:
	return {"status": &"failed", "reason": reason}
