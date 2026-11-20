class_name TrainingVoice
extends Node
## v0.3.2 · El guion hablado del Training: UNA línea a la vez (Trainer amable, monólogo del agente, compañeros de
## promoción). Cada línea: espera a que no suene ninguna otra voz (ni el cliente de una llamada), suena con su
## subtítulo, y la siguiente arranca cuando la anterior terminó más un respiro (BEAT). Nunca se pisan.
## Cada línea sale por el autoload VoiceDirector (v0.3.2-bugs: una voz y un subtítulo a la vez en todo el juego).
## Además graba la LÍNEA DE TIEMPO de todas las voces del juego mientras dura el Training (muestrea en cada fotograma
## el reproductor del VoiceDirector, el externo de su línea y los de AudioManager): `timeline()` · `overlaps()` · `write_log(path)`.
## Tutorial lo usa con `await say_all(["t_hola", "piensa:0", "promo:1", "bien"])`.
## Formato de una línea: "t_<id>" Trainer (data/lineas_trainer_amable.json; si existe voces/trainer_amable/<id>_<agente>
## suena esa: las que dicen tu nombre) · "piensa:<n>" monólogo interior del agente (turnos.json → recuerdo.piensa) ·
## "promo:<id>" compañero de promoción (turnos.json → promocion[].id, voces/promocion/<voz>) · "comodin" la respuesta
## de quien llamaste con el comodín de práctica (turnos.json → comodin) · "bien" / "casi" el elogio o el ánimo del
## Trainer (rota entre t_bien_1..n / t_casi_1..n).

signal line_started(id: String, text: String)
signal line_finished(id: String)

const BEAT := 0.45  # silencio entre dos líneas (s reales)
const WAIT_OTHER_MAX := 25.0  # tope esperando que calle otra voz (s reales)
const PRIORITY := 2  # VoiceDirector.P.DIRECTO
const PRAISE := ["t_bien_1", "t_bien_2", "t_bien_3", "t_bien_4", "t_bien_5", "t_bien_6", "t_bien_7", "t_bien_8", "t_bien_9", "t_bien_10"]
const CHEER := ["t_casi_1", "t_casi_2", "t_casi_3"]

var trainer: TrainerAmable = null
var stage: TrainingStage = null  # dirección de escena: quien habla mueve manos y boca, la clase reacciona
var current: Dictionary = {}  # la línea en curso, resuelta (id, quien, nombre, texto…)
var comodin_who: String = ""  # a quién llamaste con el comodín de práctica (lo pone Tutorial; la línea «comodin»)
var fast: bool = false  # pruebas: cada línea dura un instante, sin voz ni subtítulo (el bot no espera el audio)
var speaking: bool = false
var current_id: String = ""
var spoken: Array[String] = []  # ids en el orden en que sonaron (pruebas)
var _skip: bool = false
var _praise_i: int = 0
var _cheer_i: int = 0
var _lines: Array[Dictionary] = []  # {id, quien, texto, ini, fin, voz, saltada}
var _segments: Array[Dictionary] = []  # {bus, slot, ini, fin} de TODAS las voces (no solo las del guion)
var _open: Dictionary = {}  # reproductor -> {slot, ini, sid}
var _clock: float = 0.0
var _director: Node = null
var _line: Object = null  # la línea en curso en el director
var _vd_last: int = 0
var director_overlaps: int = 0  # solapes que registró el VoiceDirector mientras duró el Training


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_director = get_node_or_null("/root/VoiceDirector")
	_vd_last = int(_director.get("overlaps")) if _director != null else 0


## Reloj del guion: tiempo de juego sin escalar (el mismo del VoiceDirector). A 1x es el tiempo real; grabando con
## --write-movie o con el bot acelerado sigue siendo el tiempo del audio.
func _now() -> float:
	return _clock


## Dice las líneas en orden; vuelve cuando la última terminó (más el respiro).
func say_all(ids: Array) -> void:
	for id in ids:
		if not is_inside_tree():
			return
		await say(str(id))


## Una línea: se la pide al VoiceDirector (una voz y un subtítulo a la vez para TODO el juego) con prioridad DIRECTO
## y espera su `finished`; el orden y el respiro entre líneas son de aquí. Si el director está ocupado (el cliente de
## una llamada, otro aviso), espera su turno; nunca suena encima.
func say(id: String) -> void:
	var l := _resolve(id)
	if l.is_empty() or str(l.get("texto", "")) == "":
		return
	while speaking and is_inside_tree():  # otra corrutina ya habla: se pone en fila
		await get_tree().process_frame
	if not is_inside_tree():
		return
	speaking = true
	if not fast:
		await _wait_quiet()
	if not is_inside_tree():
		speaking = false
		return
	current_id = str(l["id"])
	_skip = false
	var txt := str(l["texto"])
	var shown := "%s %s" % [str(l["etiqueta"]), txt] if str(l.get("etiqueta", "")) != "" else txt
	var has_voice := str(l.get("voz", "")) != ""
	var lid := "voces/%s/%s" % [str(l["carpeta"]), str(l["voz"])] if has_voice else "training/" + current_id
	var read := clampf(1.4 + txt.length() * 0.062, 2.4, 9.0)  # sin audio: por la longitud
	var rec := {"id": current_id, "quien": str(l["quien"]), "texto": txt, "ini": _now(), "fin": -1.0, "voz": str(l.get("voz", "")), "dur": 0.0, "saltada": false, "resultado": ""}
	_lines.append(rec)
	spoken.append(current_id)
	current = l
	line_started.emit(current_id, txt)
	if stage != null and is_instance_valid(stage):
		stage.line_start(l)
	if fast:  # pruebas: la línea queda dicha al instante, sin voz ni subtítulo (no ocupa al director)
		await get_tree().process_frame
	elif _director != null:
		var line: Object = _director.call("say", lid, PRIORITY, str(l.get("hablante", "trainer_amable")), Callable(), {"text": shown, "bus": str(l.get("bus", "Sala")), "max_wait": WAIT_OTHER_MAX, "seconds": read})
		_line = line
		while line != null and not bool(line.get("done")) and is_inside_tree():
			if _skip:
				_cut(line)
				break
			await get_tree().process_frame
		_line = null
		rec["resultado"] = str(line.get("result")) if line != null else ""
	else:  # sin director (no debería pasar: es un autoload): solo el subtítulo, por su tiempo de lectura
		EventBus.subtitle.emit(str(l.get("hablante", "trainer_amable")), shown, read)
		var left := read
		while left > 0.0 and not _skip and is_inside_tree():
			await get_tree().process_frame
			left -= get_process_delta_time() / maxf(Engine.time_scale, 0.001)
	if not is_inside_tree():
		return
	rec["saltada"] = _skip
	rec["fin"] = _now()
	rec["dur"] = float(rec["fin"]) - float(rec["ini"])
	line_finished.emit(current_id)
	var beat := 0.0 if fast else BEAT
	if stage != null and is_instance_valid(stage):
		stage.line_end(l)
		if not fast and not _skip:
			beat += stage.pause_after(current_id)  # la risa o el aplauso de la clase caben en el silencio
	while beat > 0.0 and is_inside_tree():
		await get_tree().process_frame
		beat -= get_process_delta_time() / maxf(Engine.time_scale, 0.001)
	current_id = ""
	speaking = false


## Corta la línea en curso en el director (fundido de 80 ms) o la saca de su cola.
func _cut(line: Object) -> void:
	if _director == null or line == null or bool(line.get("done")):
		return
	if _director.get("current") == line:
		_director.call("_interrupt", line)
	else:
		(_director.get("queue") as Array).erase(line)
		_director.call("_drop", line, "descartada")


## [T] mientras habla: corta la línea actual (la siguiente arranca igual, nunca encima).
func skip_line() -> void:
	if speaking:
		_skip = true


## Espera a que el director esté libre (ninguna voz ni subtítulo de AMBIENTE para arriba, ni en cola) y a que no
## haya una llamada en curso (el cliente habla por el auricular). Los murmullos sueltos (BARK) no hacen esperar.
func _wait_quiet() -> void:
	var left := WAIT_OTHER_MAX
	while is_inside_tree() and left > 0.0:
		if not _any_voice() and not _call_active():
			return
		await get_tree().process_frame
		left -= get_process_delta_time() / maxf(Engine.time_scale, 0.001)


func _any_voice() -> bool:
	if _director != null and bool(_director.call("busy", 1)):
		return true
	for b in AudioManager._voice_players.keys():
		var p := AudioManager._voice_players[b] as AudioStreamPlayer
		if p != null and p.playing:
			return true
	return false


func _call_active() -> bool:
	var cm := get_tree().get_first_node_in_group("contact_manager") as ContactManager
	return cm != null and cm.phase == ContactManager.Phase.ACTIVE and str(cm.current.get("canal", "")) == "llamada"


## La línea con su texto (en el idioma actual), su voz y su etiqueta de subtítulo.
func _resolve(id: String) -> Dictionary:
	var agent := GameState.agent
	if id == "bien":
		id = PRAISE[_praise_i % PRAISE.size()]
		_praise_i += 1
	elif id == "casi":
		id = CHEER[_cheer_i % CHEER.size()]
		_cheer_i += 1
	if id.begins_with("piensa:"):
		var lines := Flashback.inner_lines(agent)
		var n := int(id.substr(7))
		if n >= lines.size():
			return {}
		var d: Dictionary = lines[n]
		return {"id": id, "quien": "piensa", "texto": Loc.pick(d), "carpeta": "agentes", "voz": str(d.get("voz", "")), "bus": "UI", "etiqueta": "(%s)" % agent, "hablante": "piensa"}
	if id.begins_with("promo:"):
		var c := _promo(id.substr(6))
		if c.is_empty():
			return {}
		var who := str(c.get("quien", "Nayra"))  # la promoción tiene nombre (turnos.json → promocion[].quien)
		return {"id": id, "quien": "promo", "nombre": who, "texto": Loc.pick(c), "carpeta": "promocion", "voz": str(c.get("voz", "")), "bus": "Sala", "etiqueta": "[%s]" % who, "hablante": "promocion"}
	if id == "comodin" or id.begins_with("comodin:"):  # quien llamaste con el comodín de práctica te contesta con su voz
		var called := id.get_slice(":", 1) if id.contains(":") else comodin_who
		var cd: Dictionary = Flashback.comodin_lines().get(called, {})
		if cd.is_empty():
			return {}
		return {"id": "comodin:" + called, "quien": "promo", "nombre": called, "texto": Loc.pick(cd), "carpeta": "promocion", "voz": str(cd.get("voz", "")), "bus": "UI", "etiqueta": "[%s]" % called, "hablante": "promocion", "telefono": true}
	var txt := PersonajesP5.line(TrainerAmable.LINES, id, {"agente": agent})
	var voz := id
	var own := "%s_%s" % [id, agent.to_lower()]
	if AudioManager.resolve("voces/%s/%s" % [TrainerAmable.VOICE, own], false) != "":
		voz = own
	return {"id": id, "quien": "trainer", "texto": txt, "carpeta": TrainerAmable.VOICE, "voz": voz, "bus": "Sala", "etiqueta": "[Trainer]", "hablante": "trainer_amable"}


## Una línea de la promoción: por su clave (turnos.json → promocion[].id) o por su número de orden.
func _promo(key: String) -> Dictionary:
	var pl := Flashback.classmate_lines()
	if key.is_valid_int():
		return pl[int(key)] if int(key) >= 0 and int(key) < pl.size() else {}
	for c in pl:
		if str((c as Dictionary).get("id", "")) == key:
			return c
	return {}


# --- línea de tiempo de las voces ----------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta / maxf(Engine.time_scale, 0.001)
	var now := _now()
	if _director != null:  # los solapes que cuenta el propio director mientras dura el Training
		var n := int(_director.get("overlaps"))
		if n > _vd_last:
			director_overlaps += n - _vd_last
		_vd_last = n
	var players := _players()
	for b in players.keys():
		var p := players[b] as Node
		var on := p != null and is_instance_valid(p) and bool(p.call("is_playing"))
		var st: Variant = p.get("stream") if on else null
		var sid := (st as AudioStream).get_instance_id() if st is AudioStream else 0
		if on:
			sid += p.get_instance_id()
		if _open.has(b):
			var o: Dictionary = _open[b]
			if not on or int(o["sid"]) != sid:
				_segments.append({"bus": b, "slot": o["slot"], "ini": o["ini"], "fin": now})
				_open.erase(b)
		if on and not _open.has(b):
			var slot := (st as AudioStream).resource_path if st is AudioStream else ""
			if slot == "" and _director != null and _director.get("current") != null:
				slot = str((_director.get("current") as Object).get("id"))
			_open[b] = {"slot": slot.replace("res://assets/audio/", ""), "ini": now, "sid": sid}
	for b in _open.keys():  # un reproductor que ya no existe (externo liberado): su tramo termina
		if not players.has(b):
			_segments.append({"bus": b, "slot": _open[b]["slot"], "ini": _open[b]["ini"], "fin": now})
			_open.erase(b)


## Todos los reproductores de voz del juego: el del VoiceDirector (el que suena ahora; el que se está fundiendo 80 ms
## al cortar una línea no cuenta, igual que en su auditoría), el externo de su línea en curso (murmullos, Shero en
## persona) y los de AudioManager (no deberían sonar fuera del director).
func _players() -> Dictionary:
	var out: Dictionary = {}
	if _director != null:
		out["director"] = _director.get("_player")
		var cur: Object = _director.get("current")
		if cur != null and cur.get("external") != null and is_instance_valid(cur.get("external")):
			out["externo"] = cur.get("external")
	for b in AudioManager._voice_players.keys():
		out["am:" + str(b)] = AudioManager._voice_players[b]
	return out


func timeline() -> Array[Dictionary]:
	return _lines


func segments() -> Array[Dictionary]:
	var out := _segments.duplicate()
	for b in _open.keys():
		out.append({"bus": b, "slot": _open[b]["slot"], "ini": _open[b]["ini"], "fin": _now()})
	return out


## Pares de voces que sonaron a la vez (en buses distintos o líneas del guion que se cruzan). Vacío = cero cruces.
func overlaps(tolerance: float = 0.05) -> Array:
	var out: Array = []
	var seg := segments()
	for i in seg.size():
		for j in range(i + 1, seg.size()):
			var a: Dictionary = seg[i]
			var b: Dictionary = seg[j]
			if minf(float(a["fin"]), float(b["fin"])) - maxf(float(a["ini"]), float(b["ini"])) > tolerance:
				out.append([a, b])
	for i in range(1, _lines.size()):
		var prev: Dictionary = _lines[i - 1]
		var cur: Dictionary = _lines[i]
		if float(prev["fin"]) < 0.0 or float(cur["ini"]) < float(prev["fin"]) - tolerance:
			out.append([prev, cur])
	return out


func write_log(path: String, header: Dictionary = {}) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_line("# AVAILABLE v0.3.2 · Training: línea de tiempo de las voces (segundos reales desde el inicio)")
	for k in header.keys():
		f.store_line("# %s: %s" % [k, str(header[k])])
	f.store_line("# GUION (una línea a la vez):  inicio → fin  dur  quién  id  texto")
	for l in _lines:
		f.store_line("%8.2f → %8.2f  %5.2fs  %-7s %-22s %s%s" % [float(l["ini"]), float(l["fin"]), float(l["fin"]) - float(l["ini"]), str(l["quien"]), str(l["id"]), str(l["texto"]), "  [cortada con T]" if bool(l["saltada"]) else ("  [%s]" % str(l.get("resultado", "")) if str(l.get("resultado", "dicha")) not in ["dicha", ""] else "")])
	f.store_line("# TODAS LAS VOCES DEL JUEGO (cada reproductor de voz, muestreado por fotograma):  inicio → fin  bus  archivo")
	for s in segments():
		f.store_line("%8.2f → %8.2f  %-10s %s" % [float(s["ini"]), float(s["fin"]), str(s["bus"]), str(s["slot"])])
	var ov := overlaps()
	if _director != null:
		f.store_line("# VOICEDIRECTOR: solapes durante el Training %d · %s" % [director_overlaps, str(_director.call("audit_line"))])
		for e in (_director.get("overlap_log") as Array):
			f.store_line("  SOLAPE %s" % str(e))
	f.store_line("# CRUCES: %d" % ov.size())
	for pair in ov:
		f.store_line("  %s  ×  %s" % [JSON.stringify(pair[0]), JSON.stringify(pair[1])])
