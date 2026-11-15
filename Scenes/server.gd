extends Node

## ONLINE VS server (run with: godot --headless --path . -- --server).
## Runs the match with the usual rules and sends its state to both games; the
## games only send their keys. Rules: "En ligne" table in 05-Etats-et-flux.
## Keeps nothing on disk and logs no addresses.

const NetProtocol = preload("res://Scenes/net_protocol.gd")
const ARENA_SCENE: PackedScene = preload("res://Scenes/arena.tscn")
## 60 physics frames per second / 3 = 20 states per second. Overridden by
## "-- --server --rate=N" (states per second) to compare.
const DEFAULT_RATE: int = 20
## Small buffers: no message is bigger than NetProtocol.MAX_MESSAGE_SIZE.
const INBOUND_BUFFER_SIZE: int = 4096
const MAX_QUEUED_PACKETS: int = 256

## One connection: waiting for its hello (player = -1), or a player.
class Client:
	var ws := WebSocketPeer.new()
	var player: int = -1
	var connected_at: float = NetProtocol.now()
	var last_message: float = NetProtocol.now()
	var last_keys: float = 0.0
	var move := Vector2.ZERO
	var ready: bool = false
	var window_start: float = NetProtocol.now()
	var window_count: int = 0

enum Match { WAITING, PLAYING, LEFT }

var tcp := TCPServer.new()
var clients: Array[Client] = []
## Connections being closed: [peer, since, close started]. Polled until done
## (WebSocketPeer docs: "Keep polling to achieve proper close"); the close only
## starts CLOSE_GRACE later, or a last "full" or "version" can be lost.
var closing: Array = []
const CLOSE_GRACE: float = 0.3
## Seconds after which a closing connection is cut without waiting.
const CLOSE_TIMEOUT: float = 2.0
var match_state: Match = Match.WAITING
var arena: Node
## Physics frames between two states sent.
var send_every: int = roundi(60.0 / DEFAULT_RATE)
var frame: int = 0


func _ready() -> void:
	# Keeps running while the arena pauses the tree on victory.
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameSettings.online = true
	GameSettings.solo = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rate="):
			var rate: float = clampf(arg.trim_prefix("--rate=").to_float(), 1.0, 60.0)
			send_every = roundi(60.0 / rate)
	var error: int = tcp.listen(NetProtocol.PORT, NetProtocol.SERVER_ADDRESS)
	if error != OK:
		push_error("Cannot listen on port %d (error %d)." % [NetProtocol.PORT, error])
		get_tree().quit(1)
		return
	print("DUEL server listening on %s:%d, %d states/s." % [
		NetProtocol.SERVER_ADDRESS, NetProtocol.PORT, 60 / send_every])

func _physics_process(_delta: float) -> void:
	while tcp.is_connection_available():
		var client := Client.new()
		client.ws.inbound_buffer_size = INBOUND_BUFFER_SIZE
		client.ws.max_queued_packets = MAX_QUEUED_PACKETS
		client.ws.accept_stream(tcp.take_connection())
		clients.append(client)

	for client in clients.duplicate():
		poll_client(client)
	poll_closing()

	apply_keys()
	frame += 1
	if arena and frame % send_every == 0:
		broadcast(state_message())

func poll_client(client: Client) -> void:
	client.ws.poll()
	var state: int = client.ws.get_ready_state()
	if state == WebSocketPeer.STATE_CLOSED:
		drop(client)
		return
	if state != WebSocketPeer.STATE_OPEN:
		if NetProtocol.now() - client.connected_at > NetProtocol.CONNECT_TIMEOUT:
			close(client)
		return
	while client.ws.get_available_packet_count() > 0:
		var packet: PackedByteArray = client.ws.get_packet()
		if not count_message(client):
			close(client)
			return
		if not client.ws.was_string_packet() or packet.size() > NetProtocol.MAX_MESSAGE_SIZE:
			continue
		var message: Dictionary = NetProtocol.decode(packet.get_string_from_utf8())
		if message.is_empty():
			continue
		client.last_message = NetProtocol.now()
		handle(client, message)
	if NetProtocol.now() - client.last_message > NetProtocol.SILENCE_TIMEOUT:
		close(client)

## False when the client sends more than MAX_MESSAGES_PER_SECOND.
func count_message(client: Client) -> bool:
	var now: float = NetProtocol.now()
	if now - client.window_start >= 1.0:
		client.window_start = now
		client.window_count = 0
	client.window_count += 1
	return client.window_count <= NetProtocol.MAX_MESSAGES_PER_SECOND

func handle(client: Client, message: Dictionary) -> void:
	var type: String = message["t"]
	if type == "ping":
		send(client, {"t": "pong", "id": message.get("id", 0)})
		return
	if client.player == -1:
		if type == "hello":
			greet(client, message)
		return
	match type:
		"keys":
			client.move = Vector2(
				clampf(float(message.get("x", 0.0)), -1.0, 1.0),
				clampf(float(message.get("y", 0.0)), -1.0, 1.0)).limit_length(1.0)
			client.last_keys = NetProtocol.now()
		"shoot":
			if arena:
				arena.players[client.player].driven_shoot = true
		"ready":
			on_ready(client)
		"leave":
			close(client)

func greet(client: Client, message: Dictionary) -> void:
	if message.get("v") != NetProtocol.VERSION:
		send(client, {"t": "version"})
		close(client)
		return
	var slot: int = free_slot()
	if slot == -1:
		send(client, {"t": "full"})
		close(client)
		return
	client.player = slot
	send(client, {"t": "welcome", "p": slot})
	if player_client(1 - slot):
		start_match()
	else:
		send(client, {"t": "waiting"})

## First free player slot while waiting for players, -1 otherwise.
func free_slot() -> int:
	if match_state != Match.WAITING:
		return -1
	for slot in 2:
		if player_client(slot) == null:
			return slot
	return -1

func player_client(slot: int) -> Client:
	for client in clients:
		if client.player == slot:
			return client
	return null

func start_match() -> void:
	match_state = Match.PLAYING
	arena = ARENA_SCENE.instantiate()
	# The server itself always runs; the arena still freezes on victory.
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(arena)

func stop_match() -> void:
	get_tree().paused = false
	if arena:
		arena.queue_free()
		arena = null

## R after a victory: a new game once both players pressed it.
func on_ready(client: Client) -> void:
	if arena == null or not arena.restart_prompt.visible:
		return
	client.ready = true
	var both: bool = true
	for slot in 2:
		var other: Client = player_client(slot)
		both = both and other != null and other.ready
	if both:
		for slot in 2:
			player_client(slot).ready = false
		arena.restart_game()

## Stale keys (paused tab, lost connection) count as released.
func apply_keys() -> void:
	if arena == null:
		return
	for slot in 2:
		var client: Client = player_client(slot)
		var fresh: bool = client != null \
			and NetProtocol.now() - client.last_keys < NetProtocol.KEYS_TIMEOUT
		arena.players[slot].driven_move = client.move if fresh else Vector2.ZERO

func close(client: Client) -> void:
	closing.append([client.ws, NetProtocol.now(), false])
	drop(client)

func poll_closing() -> void:
	var now: float = NetProtocol.now()
	for item in closing.duplicate():
		var peer: WebSocketPeer = item[0]
		peer.poll()
		# Whatever it still sends is ignored.
		while peer.get_available_packet_count() > 0:
			peer.get_packet()
		if peer.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			closing.erase(item)
		elif not item[2] and now - item[1] > CLOSE_GRACE:
			peer.close()
			item[2] = true
			item[1] = now
		elif item[2] and now - item[1] > CLOSE_TIMEOUT:
			peer.close(-1)
			closing.erase(item)

## A connection is gone: during a match the other player is told, and the
## server starts afresh once nobody is left.
func drop(client: Client) -> void:
	if not client in clients:
		return
	clients.erase(client)
	if client.player == -1:
		return
	if match_state == Match.PLAYING:
		match_state = Match.LEFT
		stop_match()
		broadcast({"t": "left", "who": client.player})
	if clients.all(func(c: Client) -> bool: return c.player == -1):
		match_state = Match.WAITING

func send(client: Client, message: Dictionary) -> void:
	if client.ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		client.ws.send_text(NetProtocol.encode(message))

func broadcast(message: Dictionary) -> void:
	for client in clients:
		if client.player != -1:
			send(client, message)

## Everything the games draw: cowboys, bullets, trees, ammo, lives, texts.
func state_message() -> Dictionary:
	var cowboys: Array = []
	for player in arena.players:
		var sprite: AnimatedSprite2D = player.anim
		cowboys.append([roundi(player.position.x), roundi(player.position.y),
			String(sprite.animation), sprite.frame, sprite.flip_h, player.ammo,
			player.player_color.to_html(false)])
	var bullets: Array = []
	for bullet in get_tree().get_nodes_in_group("bullets"):
		if not bullet.is_queued_for_deletion():
			bullets.append([roundi(bullet.position.x), roundi(bullet.position.y),
				bullet.modulate.to_html(false)])
	var trees: Array = []
	for tree in get_tree().get_nodes_in_group("trees"):
		if not tree.is_queued_for_deletion():
			trees.append([roundi(tree.position.x), roundi(tree.position.y),
				tree.color.to_html(false)])
	var ready_flags: Array = []
	for slot in 2:
		var client: Client = player_client(slot)
		ready_flags.append(client != null and client.ready)
	return {
		"t": "state", "c": cowboys, "b": bullets, "tr": trees,
		"l": arena.lives_left, "tx": arena.banner.text,
		"ty": roundi(arena.banner.position.y),
		"end": arena.restart_prompt.visible, "r": ready_flags,
	}
