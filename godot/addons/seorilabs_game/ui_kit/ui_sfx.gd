extends Node
## 하위 모든 Button의 button_down에 탭 효과음을 붙이고 종류별 효과음을 재생한다.
## 버튼 meta "ui_sfx_kind"로 confirm/cancel/error를 고르고 "ui_sfx_silent"로 제외한다.
const SELF := "res://addons/seorilabs_game/ui_kit/ui_sfx.gd"
const DIR := "res://addons/seorilabs_game/ui_kit/sfx/"
const KINDS := ["tap", "confirm", "cancel", "error", "reward_sting"]
var streams: Dictionary = {}
var plays: Dictionary = {}
var attached := 0
var enabled := true
var _root: Node
var _players: Dictionary = {}

static func attach(root: Node) -> Node:
	var existing := root.get_node_or_null("UiSfx")
	if existing != null:
		return existing
	var sfx: Node = load(SELF).new()
	sfx.name = "UiSfx"
	sfx._root = root
	root.add_child(sfx)
	return sfx

func _ready() -> void:
	for kind in KINDS:
		streams[kind] = load(DIR + kind + ".wav")
	# 오디오 장치가 없는 headless 검수에서는 호출만 세고 재생하지 않는다. 재생 중 종료되면 스트림이 누수된다.
	if AudioServer.get_driver_name() == "Dummy":
		enabled = false
	if _root != null:
		hook(_root)
	get_tree().node_added.connect(_on_node_added)

func _exit_tree() -> void:
	for player in _players.values():
		player.stop()

func _on_node_added(node: Node) -> void:
	if node is BaseButton and _root != null and _root.is_ancestor_of(node):
		hook(node)

func hook(node: Node) -> void:
	if node is BaseButton and not node.has_meta("ui_sfx") and not node.has_meta("ui_sfx_silent"):
		node.set_meta("ui_sfx", true)
		node.button_down.connect(func() -> void: play(str(node.get_meta("ui_sfx_kind", "tap"))))
		attached += 1
	for child in node.get_children():
		hook(child)

func play(kind: String) -> void:
	plays[kind] = int(plays.get(kind, 0)) + 1
	if not enabled or not streams.has(kind) or streams[kind] == null:
		return
	var player: AudioStreamPlayer = _players.get(kind)
	if player == null:
		player = AudioStreamPlayer.new()
		player.stream = streams[kind]
		player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
		add_child(player)
		_players[kind] = player
	player.play()
