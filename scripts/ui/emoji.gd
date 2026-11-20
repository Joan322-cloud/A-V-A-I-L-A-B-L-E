class_name Emoji
extends RefCounted
## Emojis de Ezlaki (v0.3.2-core). La fuente del juego (DejaVu Sans Mono) no trae emojis y antes salían como
## etiquetas de texto ([OK], [+1], [payaso]). Ahora son dibujos propios (tools/gen_emoji.py →
## assets/ui/emoji/<codepoint>.png, 64×64): en el selector, la pared de reacciones y dentro de los mensajes.
##   Emoji.bb("👍", 18)      → BBCode de la imagen para un RichTextLabel (con su nombre como tooltip y texto alternativo)
##   Emoji.rich(texto, 18)   → el texto con cada emoji conocido cambiado por su imagen (los desconocidos se quitan)
##   Emoji.plain(texto)      → para Label/subtítulos (sin BBCode): los que significan algo quedan como «[OK]» o «[+1]»,
##                             los de adorno se quitan
##   Emoji.texture("👍")     → la textura (para un TextureRect o un botón)
## Accesibilidad: el nombre de cada emoji (aquí mismo, es/en) es su tooltip y su texto alternativo; con la opción
## «Emojis como texto» (Loc.get_setting("emoji_texto")) o si falta la textura, se escribe la etiqueta en vez del dibujo.

const DIR := "res://assets/ui/emoji/"

## carácter → [archivo, nombre es, nombre en, texto plano es, texto plano en]. El texto plano es lo que queda en un
## Label o un subtítulo (sin BBCode); "" = emoji de adorno, se quita.
const TABLE := {
	"✅": ["2705", "listo", "done", "[OK]", "[OK]"],
	"👍": ["1f44d", "pulgar arriba", "thumbs up", "[+1]", "[+1]"],
	"👀": ["1f440", "ojos", "eyes", "[ojos]", "[eyes]"],
	"🫡": ["1fae1", "saludo", "salute", "[saludo]", "[salute]"],
	"🙏": ["1f64f", "gracias", "thanks", "[gracias]", "[thanks]"],
	"👌": ["1f44c", "ok", "ok", "[ok]", "[ok]"],
	"😂": ["1f602", "risa", "laughing", "[jaja]", "[haha]"],
	"🤣": ["1f923", "muerto de risa", "rolling laughing", "[jajaja]", "[lol]"],
	"🤡": ["1f921", "payaso", "clown", "[payaso]", "[clown]"],
	"💀": ["1f480", "calavera", "skull", "[calavera]", "[skull]"],
	"🙄": ["1f644", "ojos en blanco", "eye roll", "[ojos en blanco]", "[eye roll]"],
	"🚨": ["1f6a8", "alerta", "alert", "(!)", "(!)"],
	"❤": ["2764", "corazón", "heart", "", ""],
	"🔥": ["1f525", "fuego", "fire", "", ""],
	"💯": ["1f4af", "cien", "hundred", "", ""],
	"😢": ["1f622", "llanto", "crying", "", ""],
	"👏": ["1f44f", "aplauso", "clap", "", ""],
	"🎉": ["1f389", "fiesta", "party", "", ""],
	"🙌": ["1f64c", "manos arriba", "raised hands", "", ""],
	"😊": ["1f60a", "sonrisa feliz", "happy smile", "", ""],
	"🙂": ["1f642", "sonrisa", "smile", "", ""],
	"💪": ["1f4aa", "fuerza", "strong", "", ""],
	"😎": ["1f60e", "lentes oscuros", "sunglasses", "", ""],
	"😴": ["1f634", "dormido", "sleeping", "", ""],
	"😐": ["1f610", "cara neutra", "neutral face", "", ""],
	"☹": ["2639", "cara triste", "frowning", "", ""],
	"😡": ["1f621", "enojo", "angry", "", ""],
	"🤖": ["1f916", "robot", "robot", "", ""],
	"🐶": ["1f436", "perrito", "dog", "", ""],
	"🐾": ["1f43e", "huellas", "paw prints", "", ""],
	"🎤": ["1f3a4", "micrófono", "microphone", "", ""],
	"🎙": ["1f399", "micrófono", "microphone", "", ""],
	"📊": ["1f4ca", "gráfico", "chart", "", ""],
	"📈": ["1f4c8", "gráfico en alza", "chart going up", "", ""],
	"🚀": ["1f680", "cohete", "rocket", "", ""],
	"⭐": ["2b50", "estrella", "star", "", ""],
}

static var _tex: Dictionary = {}


static func has(e: String) -> bool:
	return TABLE.has(e)


static func path(e: String) -> String:
	return DIR + str((TABLE[e] as Array)[0]) + ".png" if TABLE.has(e) else ""


## Textura del emoji (null si no existe o no se pudo cargar).
static func texture(e: String) -> Texture2D:
	if not TABLE.has(e):
		return null
	if not _tex.has(e):
		var p := path(e)
		_tex[e] = load(p) as Texture2D if ResourceLoader.exists(p) else null
	return _tex[e] as Texture2D


## Nombre del emoji en el idioma del juego («pulgar arriba» / «thumbs up»); el propio carácter si no se conoce.
static func name_of(e: String) -> String:
	if not TABLE.has(e):
		return e
	var row: Array = TABLE[e]
	return str(row[2]) if Loc.language == "en" else str(row[1])


## Etiqueta de texto del emoji: la alternativa accesible («[OK]», «[+1]», «[payaso]»). Los de adorno, su nombre.
static func label(e: String) -> String:
	var pl := plain_of(e)
	return pl if pl != "" else "[%s]" % name_of(e)


## Lo que queda del emoji en texto plano ("" = de adorno o desconocido: se quita).
static func plain_of(e: String) -> String:
	if not TABLE.has(e):
		return ""
	var row: Array = TABLE[e]
	return str(row[4]) if Loc.language == "en" else str(row[3])


static func as_text() -> bool:
	return bool(Loc.get_setting("emoji_texto", false))


## BBCode del emoji para un RichTextLabel. `tip` = con tooltip (su nombre). Sin textura (o con la opción de
## accesibilidad «emojis como texto») devuelve la etiqueta de texto, escapada para BBCode.
static func bb(e: String, px: int = 18, tip: bool = true) -> String:
	if as_text() or texture(e) == null:
		return label(e).replace("[", "[lb]")
	var n := name_of(e)
	return "[img width=%d height=%d alt=\"%s\"%s]%s[/img]" % [px, px, n, (" tooltip=\"%s\"" % n) if tip else "", path(e)]


## Texto para un RichTextLabel: cada emoji conocido se cambia por su imagen; el selector de variación (U+FE0F) y los
## emojis que no están en la tabla se quitan (la fuente los pintaría como un recuadro vacío).
static func rich(text: String, px: int = 18) -> String:
	if text == "" or not _may_have_emoji(text):
		return text
	var out := ""
	for i in text.length():
		var ch := text[i]
		var code := ch.unicode_at(0)
		if code == 0xFE0F or code == 0x200D:
			continue
		if TABLE.has(ch):
			out += bb(ch, px)
		elif _is_emoji_code(code):
			continue
		else:
			out += ch
	return out


## Texto para un Label o un subtítulo (sin BBCode): los emojis con significado quedan como «[OK]»; los de adorno
## y los desconocidos se quitan (con el espacio que los separaba, para no dejar «hola  .» ni un espacio al final).
static func plain(text: String) -> String:
	if text == "" or not _may_have_emoji(text):
		return text
	var out := ""
	var removed := false  # acaba de quitarse un emoji: el espacio que sigue sobra si ya hay uno antes
	var removed_any := false
	for i in text.length():
		var ch := text[i]
		var code := ch.unicode_at(0)
		if code == 0xFE0F or code == 0x200D:
			continue
		var rep := ch
		if TABLE.has(ch):
			rep = plain_of(ch)
		elif _is_emoji_code(code):
			rep = ""
		if rep == "":
			removed = true
			removed_any = true
			continue
		if removed and ch == " " and (out == "" or out.ends_with(" ") or out.ends_with("\n")):
			continue
		removed = false
		out += rep
	return out.strip_edges(false, true) if removed_any else out


static func _is_emoji_code(code: int) -> bool:
	return code >= 0x1F000 or code == 0x2705 or code == 0x2764 or code == 0x2639 or code == 0x263A or code == 0x2B50 or code == 0x2B55 \
		or (code >= 0x2600 and code <= 0x2604) or (code >= 0x2614 and code <= 0x2615) or (code >= 0x26A0 and code <= 0x26FF) \
		or (code >= 0x2728 and code <= 0x2757 and code != 0x2731 and code != 0x2733 and code != 0x2734)


static func _may_have_emoji(text: String) -> bool:
	for i in text.length():
		var code := text.unicode_at(i)
		if code >= 0x2600:
			return true
	return false
