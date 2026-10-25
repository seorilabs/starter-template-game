extends "res://addons/seorilabs_game/flow/outgame_main.gd"
const Sample = preload("res://game/features/sample_round/sample_round.tscn")
const Home = preload("res://game/features/home/home.gd")
var sample: Node

func _init() -> void:
 var product: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/product.json"))
 game_title = product.name
 game_title_ko = product.name
 home_profile = product.homeProfile
 config.appId = product.id
 state = State.new("user://" + str(product.id) + ".json")
 lobby_art = load("res://game/assets/background.svg")
 stage_factory = func(profile: String) -> Control:
  var stage := Home.new()
  stage.profile = profile
  stage.begin = func() -> void: _open("play")
  return stage
 launch_game = _launch_round
 score_provider = func() -> Dictionary: return {"score": int(state.data.tutorial.hits) * 100, "runId": state.data.ui.get("runId", ""), "completed": state.data.tutorial.status == "complete"}

func _launch_round(owner: Control) -> void:
 if state.data.tutorial.status != "active" and not state.replay_tutorial():
  _show_error(state.error)
  return
 if sample == null:
  sample = Sample.instantiate()
  add_child(sample)
 sample.begin(owner)
