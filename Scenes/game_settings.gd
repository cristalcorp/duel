extends Node

## Choices made on the selection screen, kept between scenes (autoload
## "GameSettings"). Player 1 is index 0, player 2 is index 1.

## Videopac sprite colours, black excluded (invisible on the background).
## Exact RGB values of the console are unknown: pure colours are used.
const PALETTE: Array[Color] = [
	Color(1, 1, 1), Color(1, 0, 0), Color(0, 1, 0), Color(0, 0, 1),
	Color(1, 1, 0), Color(0, 1, 1), Color(1, 0, 1),
]

## Playable characters, in selection order. Add an entry to add a character.
const CHARACTERS: Array[Dictionary] = [
	{"name": "COWBOY", "scene": preload("res://Scenes/cowboy.tscn")},
]

## SOLO mode: player 2 is driven by the computer.
var solo: bool = false
## Set on the ONLINE VS server: both players are driven by their network keys.
var online: bool = false
const CPU_PLAYER: int = 1
## The CPU's colour: yellow, or the first colour player 1 left free.
const CPU_PREFERRED_COLOR := Color(1, 1, 0)

## Index in CHARACTERS of each player's character.
var p1_character: int = 0
var p2_character: int = 0
## Each player's colour; always two different PALETTE entries.
var p1_color: Color = Color(1, 1, 1)
var p2_color: Color = Color(1, 1, 0)


func get_color(player: int) -> Color:
	return p1_color if player == 0 else p2_color

func set_color(player: int, color: Color) -> void:
	if player == 0:
		p1_color = color
	else:
		p2_color = color

func get_character(player: int) -> int:
	return p1_character if player == 0 else p2_character

func set_character(player: int, index: int) -> void:
	if player == 0:
		p1_character = index
	else:
		p2_character = index

func is_cpu(player: int) -> bool:
	return solo and player == CPU_PLAYER

## "PLAYER n", or "CPU" for the computer.
func player_name(player: int) -> String:
	return "CPU" if is_cpu(player) else "PLAYER %d" % (player + 1)

## In SOLO, gives the CPU its preferred colour unless player 1 has it.
func pick_cpu_color() -> void:
	var taken: Color = get_color(1 - CPU_PLAYER)
	var color: Color = CPU_PREFERRED_COLOR
	if color == taken:
		color = PALETTE[0] if PALETTE[0] != taken else PALETTE[1]
	set_color(CPU_PLAYER, color)
