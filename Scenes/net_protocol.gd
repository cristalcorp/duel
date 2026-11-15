extends RefCounted

## ONLINE VS protocol shared by the server and the game (preloaded as
## NetProtocol). Messages are JSON text frames with a "t" (type) field. Rules
## and message list: "Flux" and "En ligne" tables in 05-Etats-et-flux.
##
## Game -> server: hello {v}, keys {x, y}, shoot, ready, leave, ping {id}.
## Server -> game: welcome {p}, waiting, full, version, left {who},
##                 state {...}, pong {id}.

const VERSION: int = 1
const PORT: int = 8910
## Step 1 is a local test: the server only listens on this machine.
const SERVER_ADDRESS: String = "127.0.0.1"
## Messages from a game bigger than this are ignored by the server (bytes).
const MAX_MESSAGE_SIZE: int = 256
## Over this, the server closes the connection.
const MAX_MESSAGES_PER_SECOND: int = 120
## No keys message for this long: all keys count as released.
const KEYS_TIMEOUT: float = 0.5
## No message at all for this long: the player is gone.
const SILENCE_TIMEOUT: float = 5.0
## The game repeats its keys this often even when they do not change, so the
## server can tell a held key from a paused tab.
const KEYS_REPEAT: float = 0.25
const PING_INTERVAL: float = 1.0
const CONNECT_TIMEOUT: float = 5.0


static func encode(message: Dictionary) -> String:
	return JSON.stringify(message)

## The message as a Dictionary with a String "t", or an empty one if malformed.
## The server checks the size itself before decoding.
static func decode(text: String) -> Dictionary:
	var data: Variant = JSON.parse_string(text)
	if data is Dictionary and data.get("t") is String:
		return data
	return {}

static func now() -> float:
	return Time.get_ticks_msec() / 1000.0
