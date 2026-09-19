extends SceneTree

const MODELS := [
	"res://assets/models/drone.glb",
	"res://assets/models/gunship.glb",
	"res://assets/models/turret.glb",
	"res://assets/models/enemy_crawler.glb",
	"res://assets/models/boss.glb",
]

func _initialize() -> void:
	for path in MODELS:
		var scene := load(path) as PackedScene
		var instance := scene.instantiate()
		var clips: Array[String] = []
		_collect_clips(instance, clips)
		print("ASSET QA: %s clips=%s" % [path.get_file(), clips])
		instance.free()
	quit()

func _collect_clips(node: Node, clips: Array[String]) -> void:
	if node is AnimationPlayer:
		for clip in (node as AnimationPlayer).get_animation_list():
			clips.append(String(clip))
	for child in node.get_children():
		_collect_clips(child, clips)
