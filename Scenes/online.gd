extends Node2D

## ONLINE VS game side: sends this player's keys to the server and draws the
## state it sends back, with no prediction (step 1 measures the raw lag).
## "-- --delay=N" adds N ms to every message, both ways, to simulate a network.
## Rules: "En ligne" table in 05-Etats-et-flux.

const NetProtocol = preload("res://Scenes/net_protocol.gd")
const MAIN_MENU_SCENE: String = "res://Scenes/main_menu.tscn"
const ARENA_SCRIPT: Script = preload("res://Scenes/arena.gd")
const COWBOY_SCENE: PackedScene = preload("res://Scenes/cowboy.tscn")
const TREE_SCENE: PackedScene = preload("res://Scenes/tree.tscn")
const BULLET_SIZE: float = 8.0
const MAX_AMMO: int = 5

enum Screen { CONNECTING, WAITING, PLAYING, MESSAGE }

var ws := WebSocketPeer.new()
var screen: Screen = Screen.CONNECTING
var started_at: float = NetProtocol.now()
var opened: bool = false
## Simulated network delay, each way, in seconds.
var delay: float = 0.0
## [due time, text] waiting for the simulated delay.
var outgoing: Array = []
var incoming: Array = []
var my_player: int = -1
var sent_move := Vector2.INF
var last_keys_sent: float = 0.0
var next_ping_id: int = 0
var pings: Dictionary = {}
var last_ping: float = 0.0

var message_label: Label
var ping_label: Label
var banner: Label
var prompt: Label
var cowboys: Array[Node2D] = []
var trees_data: Array = []
var trees: Array[Node2D] = []
var bullets: Array[ColorRect] = []
var ammo_rows: Array[Node2D] = []
var lives_labels: Array[Label] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--delay="):
			delay = clampf(arg.trim_prefix("--delay=").to_float(), 0.0, 2000.0) / 1000.0
	var width: float = get_viewport_rect().size.x
	message_label = make_label("CONNECTING...", 16)
	message_label.size = Vector2(width, 40)
	message_label.position.y = 130
	ping_label = make_label("", 10)
	ping_label.size = Vector2(150, 14)
	ping_label.position = Vector2(width - 154, 2)
	ping_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ping_label.z_index = 2
	ws.connect_to_url("ws://%s:%d" % [NetProtocol.SERVER_ADDRESS, NetProtocol.PORT])

func make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _process(_delta: float) -> void:
	ws.poll()
	var state: int = ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN and not opened:
		opened = true
		send({"t": "hello", "v": NetProtocol.VERSION})
	# Also read after closing: "full" or "version" arrive just before the close.
	while ws.get_available_packet_count() > 0:
		var packet: PackedByteArray = ws.get_packet()
		incoming.append([NetProtocol.now() + delay, packet.get_string_from_utf8()])
	flush_delayed()

	if state == WebSocketPeer.STATE_CLOSED and screen != Screen.MESSAGE and incoming.is_empty():
		show_message("CONNECTION LOST" if opened else "NO SERVER")
	elif not opened and NetProtocol.now() - started_at > NetProtocol.CONNECT_TIMEOUT:
		ws.close()
		show_message("NO SERVER")

	if opened and screen != Screen.MESSAGE:
		send_keys()
		send_ping()

## Hands over the messages whose simulated delay is over, in order.
func flush_delayed() -> void:
	var now: float = NetProtocol.now()
	while not outgoing.is_empty() and outgoing[0][0] <= now:
		if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			ws.send_text(outgoing.pop_front()[1])
		else:
			outgoing.clear()
	while not incoming.is_empty() and incoming[0][0] <= now:
		var message: Dictionary = NetProtocol.decode(incoming.pop_front()[1])
		if not message.is_empty():
			handle(message)

func send(message: Dictionary) -> void:
	outgoing.append([NetProtocol.now() + delay, NetProtocol.encode(message)])

## One player per machine: both key sets move the same cowboy.
func send_keys() -> void:
	var move := Vector2(
		Input.get_axis("move_left", "move_right") + Input.get_axis("move_left_p2", "move_right_p2"),
		Input.get_axis("move_up", "move_down") + Input.get_axis("move_up_p2", "move_down_p2"))
	move = move.clamp(-Vector2.ONE, Vector2.ONE).limit_length(1.0)
	var now: float = NetProtocol.now()
	if move != sent_move or now - last_keys_sent >= NetProtocol.KEYS_REPEAT:
		send({"t": "keys", "x": snappedf(move.x, 0.01), "y": snappedf(move.y, 0.01)})
		sent_move = move
		last_keys_sent = now

func send_ping() -> void:
	var now: float = NetProtocol.now()
	if now - last_ping < NetProtocol.PING_INTERVAL:
		return
	last_ping = now
	next_ping_id += 1
	pings[next_ping_id] = now
	send({"t": "ping", "id": next_ping_id})

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("menu"):
		if opened and screen != Screen.MESSAGE:
			# Sent at once: the scene is about to go.
			ws.send_text(NetProtocol.encode({"t": "leave"}))
		ws.close()
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	elif screen == Screen.PLAYING and (event.is_action_pressed("shoot") or event.is_action_pressed("shoot_p2")):
		send({"t": "shoot"})
	elif screen == Screen.PLAYING and event.is_action_pressed("restart"):
		send({"t": "ready"})

func handle(message: Dictionary) -> void:
	match message["t"]:
		"pong":
			var sent: Variant = pings.get(int(message.get("id", 0)))
			if sent != null:
				ping_label.text = "%d ms" % roundi((NetProtocol.now() - sent) * 1000.0)
				pings.clear()
		"welcome":
			my_player = int(message.get("p", -1))
		"waiting":
			screen = Screen.WAITING
			message_label.text = "WAITING FOR PLAYER 2\n\nPress M for menu"
		"full":
			show_message("GAME FULL")
		"version":
			show_message("UPDATE THE GAME")
		"left":
			show_message("PLAYER %d LEFT" % (int(message.get("who", 0)) + 1))
		"state":
			draw_state(message)

func show_message(text: String) -> void:
	screen = Screen.MESSAGE
	clear_game()
	message_label.text = text + "\n\nPress M for menu"
	message_label.visible = true

func clear_game() -> void:
	for node in cowboys + trees + bullets + ammo_rows:
		node.queue_free()
	cowboys.clear()
	trees.clear()
	bullets.clear()
	ammo_rows.clear()
	lives_labels.clear()
	trees_data = []
	for label in [banner, prompt]:
		if label:
			label.text = ""

func draw_state(state: Dictionary) -> void:
	if screen != Screen.PLAYING:
		screen = Screen.PLAYING
		message_label.visible = false
		build_game(state)
	var data: Array = state.get("c", [])
	for i in mini(data.size(), cowboys.size()):
		draw_cowboy(i, data[i])
	draw_trees(state.get("tr", []))
	draw_bullets(state.get("b", []))
	var lives: Array = state.get("l", [])
	for i in mini(lives.size(), lives_labels.size()):
		lives_labels[i].text = str(int(lives[i]))
	banner.text = str(state.get("tx", ""))
	banner.position.y = float(state.get("ty", 4))
	prompt.visible = bool(state.get("end", false))
	if prompt.visible:
		prompt.position.y = banner.position.y + ARENA_SCRIPT.BANNER_HEIGHT
		var ready_flags: Array = state.get("r", [false, false])
		var text := "Press R to restart\nPress M for menu"
		for i in ready_flags.size():
			if ready_flags[i]:
				text += "\nPLAYER %d READY" % (i + 1)
		prompt.text = text

## Cowboys, ammo rows and lives counters, the same layout as the arena.
func build_game(state: Dictionary) -> void:
	var width: float = get_viewport_rect().size.x
	var data: Array = state.get("c", [])
	for i in data.size():
		var cowboy: Node2D = COWBOY_SCENE.instantiate()
		# Drawn only: the server moves it.
		cowboy.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(cowboy)
		cowboy.modulate = Color.html(str(data[i][6]))
		cowboys.append(cowboy)
		add_ammo_row(i, cowboy.modulate)
	banner = make_label("", 16)
	banner.size = Vector2(width, ARENA_SCRIPT.BANNER_HEIGHT)
	banner.z_index = 1
	prompt = make_label("", 10)
	prompt.size = Vector2(width, 0)
	prompt.z_index = 1

func add_ammo_row(player: int, color: Color) -> void:
	var row := Node2D.new()
	row.z_index = 1
	add_child(row)
	ammo_rows.append(row)
	var icon_size: float = ARENA_SCRIPT.AMMO_ICON_SIZE
	var gap: float = ARENA_SCRIPT.AMMO_ICON_GAP
	var hud_height: float = ARENA_SCRIPT.HUD_HEIGHT
	var width: float = MAX_AMMO * icon_size + (MAX_AMMO - 1) * gap
	var top: float = get_viewport_rect().end.y - hud_height + (hud_height - icon_size) / 2.0
	row.position = Vector2(ARENA_SCRIPT.PLAYER_STARTS[player].x - width / 2.0, top)
	for i in MAX_AMMO:
		var icon := ColorRect.new()
		icon.color = color
		icon.size = Vector2.ONE * icon_size
		icon.position.x = i * (icon_size + gap)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	var counter := Label.new()
	counter.add_theme_font_size_override("font_size", 14)
	counter.add_theme_color_override("font_color", color)
	counter.size = Vector2(16, hud_height)
	counter.position = Vector2(-16 - ARENA_SCRIPT.LIVES_GAP,
		(icon_size - hud_height) / 2.0 + ARENA_SCRIPT.LIVES_Y_OFFSET)
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(counter)
	lives_labels.append(counter)

## [x, y, animation, frame, facing left, ammo, colour]
func draw_cowboy(index: int, data: Array) -> void:
	var cowboy: Node2D = cowboys[index]
	cowboy.position = Vector2(data[0], data[1])
	var sprite: AnimatedSprite2D = cowboy.get_node("AnimatedSprite2D")
	var animation := StringName(str(data[2]))
	if sprite.sprite_frames.has_animation(animation):
		sprite.animation = animation
		sprite.frame = int(data[3])
	sprite.flip_h = bool(data[4])
	var ammo: int = int(data[5])
	for i in MAX_AMMO:
		ammo_rows[index].get_child(i).visible = i < ammo

## Trees only change at a new round: rebuilt when the list differs.
func draw_trees(data: Array) -> void:
	if data == trees_data:
		return
	trees_data = data
	for tree in trees:
		tree.queue_free()
	trees.clear()
	for item in data:
		var tree: Node2D = TREE_SCENE.instantiate()
		tree.process_mode = Node.PROCESS_MODE_DISABLED
		tree.position = Vector2(item[0], item[1])
		add_child(tree)
		tree.color = Color.html(str(item[2]))
		trees.append(tree)

func draw_bullets(data: Array) -> void:
	while bullets.size() < data.size():
		var bullet := ColorRect.new()
		bullet.size = Vector2.ONE * BULLET_SIZE
		bullet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bullet)
		bullets.append(bullet)
	for i in bullets.size():
		var shown: bool = i < data.size()
		bullets[i].visible = shown
		if shown:
			bullets[i].position = Vector2(data[i][0], data[i][1]) - bullets[i].size / 2.0
			bullets[i].color = Color.html(str(data[i][2]))
