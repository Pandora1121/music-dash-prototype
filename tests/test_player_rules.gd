extends SceneTree

func _initialize() -> void:
	var player_script: Script = load("res://scripts/player.gd")
	assert(player_script != null, "player script should exist")
	var player: CharacterBody2D = player_script.new()
	assert(player.try_jump(true), "grounded player should jump")
	assert(not player.try_jump(false), "airborne player should not jump again")
	player.crash()
	assert(not player.try_jump(true), "crashed player should not move")
	player.reset_player()
	assert(player.try_jump(true), "reset player should jump again")
	player.free()
	print("PASS: player rules")
	quit()
