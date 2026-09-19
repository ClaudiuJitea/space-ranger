extends Node

## Regression probe: FX pools must survive scene teardown + reload.

func _ready() -> void:
	_run()

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _run() -> void:
	for i in 2:
		var lvl: Node = load("res://src/levels/level_01.tscn").instantiate()
		add_child(lvl)
		await _wait(1.0)
		Input.action_press("shoot")
		await _wait(0.4)
		Input.action_release("shoot")
		lvl.queue_free()
		await _wait(0.3)
	print("RESTART CYCLE OK")
	get_tree().quit()
