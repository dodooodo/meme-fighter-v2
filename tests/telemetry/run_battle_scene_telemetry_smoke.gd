# Headless A4 smoke: real BattleScene ready/reset/finalize path with project autoload.
extends SceneTree

const BATTLE_SCENE := preload("res://battle/battle_scene.tscn")

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var failures := 0
    var telemetry_directory := OS.get_temp_dir().path_join("meme_fighter_a4_live_scene_telemetry")
    var replay_directory := OS.get_temp_dir().path_join("meme_fighter_a4_live_scene_replays")
    var service := get_root().get_node_or_null("Telemetry") as TelemetryService
    if service == null or not service.configure("installation-smoke", "session-smoke", telemetry_directory, 64, "build-smoke", "content-smoke", "test"):
        push_error("[FAIL] Project Telemetry autoload configures for BattleScene smoke")
        quit(1)
        return

    var scene := BATTLE_SCENE.instantiate() as BattleScene
    if scene == null:
        push_error("[FAIL] BattleScene instantiates")
        quit(1)
        return
    scene.replay_directory = replay_directory
    get_root().add_child(scene)
    if scene.simulation == null or scene.replay_recorder == null:
        push_error("[FAIL] BattleScene ready path starts simulation and replay recording")
        failures += 1
    else:
        scene.simulation.simulate_frame(InputFrame.neutral(1), InputFrame.neutral(1))
        scene._consume_simulation_events(scene.simulation.drain_events())
        scene._finalize_match("reset")
        service.flush_blocking(999)

    var replay_path := replay_directory.path_join("%s%s" % [scene.replay_id, ReplayFormat.FILE_EXTENSION])
    if not FileAccess.file_exists(replay_path):
        push_error("[FAIL] BattleScene smoke saves replay")
        failures += 1
    var found_match := false
    var telemetry_path := service.output_path()
    var file := FileAccess.open(telemetry_path, FileAccess.READ)
    while file != null and file.get_position() < file.get_length():
        var parsed: Variant = JSON.parse_string(file.get_line())
        if typeof(parsed) == TYPE_DICTIONARY and parsed.get("event_name", "") == "match.completed" and parsed.get("payload", {}).get("replay_saved", false):
            found_match = true
    if file != null:
        file.close()
    if not found_match:
        push_error("[FAIL] BattleScene smoke writes correlated match summary")
        failures += 1

    get_root().remove_child(scene)
    scene.free()
    if FileAccess.file_exists(replay_path):
        DirAccess.remove_absolute(replay_path)
    if FileAccess.file_exists(telemetry_path):
        DirAccess.remove_absolute(telemetry_path)
    DirAccess.remove_absolute(replay_directory)
    DirAccess.remove_absolute(telemetry_directory)
    if failures == 0:
        print("A4 BattleScene telemetry smoke: PASS")
    quit(failures)
