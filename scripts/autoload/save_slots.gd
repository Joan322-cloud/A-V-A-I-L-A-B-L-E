extends Node
## SaveSlots (v0.3, PLAN §3.7): una partida por agente jugable. Cada agente tiene su carpeta
## user://partidas/<agente>/ con progreso.json (turno desbloqueado, turnos cerrados, saldo, modo,
## dificultad, finales vistos) y checkpoint.json (el checkpoint del turno en curso). Así un checkpoint
## nunca puede cruzar de un agente a otro (bug de colapso de la v0.2, PLAN §1).
## API: SaveSlots.current (agente activo) · select(agente) · load(agente) · save(agente) · new(agente)
##      progress(agente) · summary(agente) · read/write/delete_checkpoint(agente) · migrate_v02().
## La partida única de la v0.2 (user://progreso.json + user://save_slot_1.json) se migra al arrancar a la
## carpeta del agente guardado y los archivos viejos quedan como *.v02.bak.
##
## v0.3 P6b · Elegir turno (PLAN §2 #80): progreso.json guarda una INSTANTÁNEA al inicio de cada turno que el
## agente alcanzó (`turnos`: {"1": {...}, "2": {...}}) con lo que hace falta para volver a empezarlo igual:
## saldo, turno desbloqueado, turnos cerrados, dificultad, modo, Fatiga base, WW acumulados, contadores de
## elecciones/finales y memos desbloqueados; al cerrar ese turno se le añade el `resultado` (Available, WW,
## incidencias…). Rejugar un turno pasado es una RAMA aparte (contexto "rama", carpeta <agente>/rama/): la
## partida principal no cambia salvo que al terminar el turno el jugador elija "Seguir desde aquí"
## (end_branch(true): reemplaza el progreso posterior). Los finales, epílogos y memos desbloqueados quedan en
## la partida principal para siempre (unlock_ending/unlock_epilogue/unlock_memo escriben en las dos).
## La Inducción (tutorial, contexto "induccion") usa su propia carpeta (<root>/_induccion/): nunca toca la
## partida del agente. Contextos: "" (principal) · "rama" · "induccion"; solo afectan al agente activo.
## Migración v3 → v4: las partidas sin instantáneas reciben una por turno alcanzado (marcadas `migrado`).

const VERSION := 4
const CTX_MAIN := ""
const CTX_BRANCH := "rama"
const CTX_TUTORIAL := "induccion"
const TUTORIAL_DIR := "_induccion/"
const DEFAULT_ROOT := "user://partidas/"
const DEFAULT_LEGACY_DIR := "user://"

var root: String = DEFAULT_ROOT  # los escenarios de prueba usan una carpeta aparte (sandbox)
var legacy_dir: String = DEFAULT_LEGACY_DIR
var current: String = "Jiroshi"
var _cache: Dictionary = {}  # "agente|contexto" -> progreso cargado
## Contexto de guardado del agente activo: "" principal · "rama" (turno rejugado) · "induccion" (tutorial).
var context: String = CTX_MAIN


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	migrate_v02()
	var last := str(Loc.get_setting("last_agent", "Jiroshi"))
	current = last if GameState.PLAYABLE_AGENTS.has(last) else "Jiroshi"
	var args := OS.get_cmdline_user_args()
	var i := args.find("--slot")
	if i >= 0 and i + 1 < args.size():
		var a := agent_from(args[i + 1])
		if a != "":
			current = a
	_apply_difficulty()


## "marko" / "Marko" → "Marko" ("" si no es un agente jugable).
static func agent_from(s: String) -> String:
	for a in GameState.AGENTS:
		if a.to_lower() == s.to_lower():
			return a
	return ""


static func slug(agent: String) -> String:
	return agent.to_lower()


func dir_of(agent: String) -> String:
	return root + slug(agent) + "/"


## Carpeta del contexto activo para ese agente (el contexto solo vale para el agente activo).
func ctx_dir(agent: String) -> String:
	match _ctx_of(agent):
		CTX_BRANCH:
			return dir_of(agent) + "rama/"
		CTX_TUTORIAL:
			return root + TUTORIAL_DIR
	return dir_of(agent)


func _ctx_of(agent: String) -> String:
	return context if agent == current else CTX_MAIN


func progress_path(agent: String) -> String:
	return ctx_dir(agent) + "progreso.json"


func checkpoint_path(agent: String) -> String:
	return ctx_dir(agent) + "checkpoint.json"


## Rutas de la partida PRINCIPAL (sin importar el contexto activo).
func main_progress_path(agent: String) -> String:
	return dir_of(agent) + "progreso.json"


func main_checkpoint_path(agent: String) -> String:
	return dir_of(agent) + "checkpoint.json"


func has_main_checkpoint(agent: String = "") -> bool:
	return FileAccess.file_exists(main_checkpoint_path(current if agent == "" else agent))


func branch_meta_path(agent: String) -> String:
	return dir_of(agent) + "rama/rama.json"


func default_progress(agent: String) -> Dictionary:
	return {
		"version": VERSION, "agente": agent, "turno_desbloqueado": 1, "turnos_cerrados": [],
		"saldo": -1.0, "mode": 0, "dificultad": "facil" if _ctx_of(agent) == CTX_TUTORIAL else "normal",
		"finales": [], "epilogos": [], "memos": [], "contadores": {}, "ww_total": 0, "turnos": {},
		"tooltips_vistos": [], "creada": "", "actualizada": "", "duracion_turno": "normal",
	}


## Cambia la partida activa (menú o inicio de turno). Aplica su dificultad guardada.
func select(agent: String) -> void:
	if not GameState.AGENTS.has(agent):
		return
	var changed := agent != current
	current = agent
	Loc.set_setting("last_agent", agent)
	_apply_difficulty()
	if changed:
		EventBus.slot_changed.emit(agent)


## Progreso (en memoria, cargado la primera vez) del agente; se modifica en sitio y se guarda con save().
func progress(agent: String = "") -> Dictionary:
	var a := current if agent == "" else agent
	var key := _key(a)
	if not _cache.has(key):
		_load_slot(a)
	return _cache[key]


func _key(agent: String) -> String:
	return agent + "|" + _ctx_of(agent)


## Relee del disco la partida del agente (o crea una vacía en memoria si no existe).
## (Dentro de esta clase `load()` sería el load() global de Godot: se usa _load_slot.)
func load(agent: String = "") -> Dictionary:
	return _load_slot(current if agent == "" else agent)


func _load_slot(a: String) -> Dictionary:
	var d := default_progress(a)
	var parsed: Variant = _read_json(progress_path(a))
	var old_version := VERSION
	if parsed is Dictionary:
		old_version = int((parsed as Dictionary).get("version", 1))
		for k in (parsed as Dictionary).keys():
			d[k] = parsed[k]
	d["version"] = VERSION
	d["agente"] = a
	_normalize(d)
	_cache[_key(a)] = d
	if parsed is Dictionary and _ctx_of(a) == CTX_MAIN and _migrate_v4(d, old_version):
		_write_json(progress_path(a), d)  # la migración queda en disco aunque no se juegue
	return d


func save(agent: String = "") -> void:
	var a := current if agent == "" else agent
	var d := progress(a)
	if str(d.get("creada", "")) == "":
		d["creada"] = Time.get_datetime_string_from_system()
	d["actualizada"] = Time.get_datetime_string_from_system()
	_write_json(progress_path(a), d)


## Nueva partida: borra la historia del agente (progreso y checkpoint). La confirmación la pide el menú.
func new(agent: String = "") -> void:
	var a := current if agent == "" else agent
	for p in [progress_path(a), checkpoint_path(a)]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	if _ctx_of(a) == CTX_MAIN:
		_remove_branch_files(a)
	_cache[_key(a)] = default_progress(a)
	if a == current:
		_apply_difficulty()


func exists(agent: String = "") -> bool:
	var a := current if agent == "" else agent
	return FileAccess.file_exists(progress_path(a)) or FileAccess.file_exists(checkpoint_path(a))


func has_checkpoint(agent: String = "") -> bool:
	return FileAccess.file_exists(checkpoint_path(current if agent == "" else agent))


func read_checkpoint(agent: String = "") -> Dictionary:
	var parsed: Variant = _read_json(checkpoint_path(current if agent == "" else agent))
	return parsed if parsed is Dictionary else {}


func write_checkpoint(agent: String, d: Dictionary) -> void:
	_write_json(checkpoint_path(agent), d)


func delete_checkpoint(agent: String = "") -> void:
	var p := checkpoint_path(current if agent == "" else agent)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## Estado de la partida para el menú: {existe, turno, desbloqueado, saldo, dificultad, checkpoint, cp_turno, cp_hora}.
func summary(agent: String = "") -> Dictionary:
	var a := current if agent == "" else agent
	var p := progress(a)
	var closed: Array = p.get("turnos_cerrados", [])
	var nxt := 1
	while closed.has(nxt) and nxt < 10:
		nxt += 1
	nxt = mini(nxt, maxi(int(p.get("turno_desbloqueado", 1)), 1))
	var cp := read_checkpoint(a)
	var gs: Dictionary = cp.get("game_state", {})
	return {
		"existe": exists(a), "turno": nxt, "desbloqueado": int(p.get("turno_desbloqueado", 1)),
		"saldo": float(p.get("saldo", -1.0)), "dificultad": str(p.get("dificultad", "normal")),
		"modo": int(p.get("mode", 0)), "checkpoint": not cp.is_empty(),
		"cp_turno": int(gs.get("turno", 0)), "cp_hora": float(gs.get("clock_seconds", 0.0)),
		"finales": (p.get("finales", []) as Array).size(),
	}


## Línea del menú: "Marko · Turno 2 · S/ 54.50 · Normal" o "Marko · Sin partida".
func summary_text(agent: String = "") -> String:
	var a := current if agent == "" else agent
	var s := summary(a)
	if not bool(s.get("existe", false)):
		return Loc.fmt(tr("SLOT_EMPTY"), {"agente": a})
	var saldo := float(s.get("saldo", -1.0))
	var dif := tr(Difficulty.NAME_KEYS[Difficulty.level_from_id(str(s.get("dificultad", "normal")))])
	if int(s.get("modo", 0)) == GameState.Mode.REAL:
		dif = tr("MENU_MODE_REAL")
	var txt := Loc.fmt(tr("SLOT_LINE"), {"agente": a, "n": int(s.get("turno", 1)), "dia": Days.full(int(s.get("turno", 1))), "saldo": Economy.soles(saldo) if saldo >= 0.0 else "—", "dif": dif})
	if bool(s.get("checkpoint", false)):
		txt += "  ·  " + Loc.fmt(tr("SLOT_IN_PROGRESS"), {"n": int(s.get("cp_turno", 1)), "dia": Days.day_name(int(s.get("cp_turno", 1))), "hora": GameState.clock_text_at(float(s.get("cp_hora", 0.0)))})
	return txt


func _apply_difficulty() -> void:
	if not is_inside_tree():
		return
	var p := progress(current)
	Difficulty.set_level(Difficulty.level_from_id(str(p.get("dificultad", "normal"))))


## Guarda la dificultad elegida en la partida del agente activo.
func set_difficulty(level: int) -> void:
	var p := progress(current)
	p["dificultad"] = Difficulty.IDS[clampi(level, 0, Difficulty.IDS.size() - 1)]
	Difficulty.set_level(level)
	if exists(current):
		save(current)


## El JSON devuelve los números como float: [1.0, 2.0].has(1) es false en Godot 4, así que "Continuar" leía mal
## los turnos cerrados de una partida recién cargada del disco. Aquí todo lo que es un número de turno vuelve a int.
static func _normalize(d: Dictionary) -> void:
	d["turno_desbloqueado"] = int(d.get("turno_desbloqueado", 1))
	d["turnos_cerrados"] = _ints(d.get("turnos_cerrados", []))
	d["mode"] = int(d.get("mode", 0))
	d["ww_total"] = int(d.get("ww_total", 0))
	var turns: Variant = d.get("turnos", {})
	if turns is Dictionary:
		for k in (turns as Dictionary).keys():
			var sn: Variant = turns[k]
			if sn is Dictionary:
				(sn as Dictionary)["turno"] = int((sn as Dictionary).get("turno", int(k)))
				(sn as Dictionary)["turno_desbloqueado"] = int((sn as Dictionary).get("turno_desbloqueado", int(k)))
				(sn as Dictionary)["turnos_cerrados"] = _ints((sn as Dictionary).get("turnos_cerrados", []))
				(sn as Dictionary)["mode"] = int((sn as Dictionary).get("mode", 0))
				(sn as Dictionary)["ww_total"] = int((sn as Dictionary).get("ww_total", 0))
	if d.has("rama_de"):
		d["rama_de"] = int(d["rama_de"])


static func _ints(a: Variant) -> Array:
	var out: Array = []
	for v in (a if a is Array else []):
		if not out.has(int(v)):
			out.append(int(v))
	return out


# --- Contextos: principal · rama (elegir turno) · inducción ----------------------------------------

## Vuelve a la partida principal del agente activo (menú, iniciar un turno normal).
func use_main() -> void:
	if context == CTX_MAIN:
		return
	context = CTX_MAIN
	_apply_difficulty()


func in_branch() -> bool:
	return context == CTX_BRANCH


func in_tutorial() -> bool:
	return context == CTX_TUTORIAL


## Inducción: carpeta propia (<root>/_induccion/), Fácil por defecto. Nunca toca la partida del agente.
func begin_tutorial() -> void:
	context = CTX_TUTORIAL
	_cache.erase(_key(current))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root + TUTORIAL_DIR))
	_apply_difficulty()


func end_tutorial() -> void:
	if context == CTX_TUTORIAL:
		use_main()


# --- v0.3.2 · Training y contrato ---------------------------------------------------------------------

## ¿La partida de este agente necesita el Training obligatorio antes del Lunes? Solo si no existe todavía (partida
## nueva o «Nueva partida»). Las partidas que ya existían (v0.3 / v0.3.1) lo saltan: se da por firmado.
func needs_training(agent: String = "") -> bool:
	var a := current if agent == "" else agent
	return not FileAccess.file_exists(main_progress_path(a)) and not FileAccess.file_exists(main_checkpoint_path(a))


## El contrato firmado en el Training queda en la partida principal (y la crea): {firmado, leido, fecha}.
func sign_contract(agent: String, read_all: bool, mode: int = -1) -> void:
	var a := current if agent == "" else agent
	var prev := context
	context = CTX_MAIN
	var p := progress(a)
	p["contrato"] = {"firmado": true, "leido": read_all, "fecha": Time.get_datetime_string_from_system()}
	if mode >= 0:
		p["mode"] = mode
	p["dificultad"] = str(p.get("dificultad", "normal"))
	save(a)
	context = prev
	_apply_difficulty()


func contract(agent: String = "") -> Dictionary:
	var a := current if agent == "" else agent
	var c: Variant = main_progress(a).get("contrato", {})
	return c if c is Dictionary else {}


# --- Instantáneas por turno (Elegir turno, PLAN §2 #80) --------------------------------------------

## Fatiga con la que empieza el turno n (turnos.json/fatiga_inicio, la misma fórmula que Fatigue).
static func fatigue_base_of(n: int) -> float:
	for t in DataLoader.list("turnos"):
		if int(t.get("turno", 0)) == n and t.has("fatiga_inicio"):
			return float(t.get("fatiga_inicio"))
	return float(DataLoader.bal("fatiga/inicio_t1", 20.0)) + float(DataLoader.bal("fatiga/inicio_por_turno", 5.0)) * (n - 1)


## Instantánea del estado de la partida (contexto activo) al empezar el turno n.
func make_snapshot(agent: String, n: int) -> Dictionary:
	var p := progress(agent)
	return {
		"turno": n, "alcanzado": Time.get_datetime_string_from_system(),
		"saldo": float(p.get("saldo", -1.0)), "turno_desbloqueado": maxi(int(p.get("turno_desbloqueado", 1)), n),
		"turnos_cerrados": (p.get("turnos_cerrados", []) as Array).duplicate(),
		"dificultad": str(p.get("dificultad", "normal")), "mode": int(p.get("mode", 0)),
		"fatiga_base": fatigue_base_of(n), "ww_total": int(p.get("ww_total", 0)),
		"contadores": (p.get("contadores", {}) as Dictionary).duplicate(true),
		"memos": (p.get("memos", []) as Array).duplicate(),
		"finales": (p.get("finales", []) as Array).duplicate(),
	}


## Guarda la instantánea del inicio del turno n (si `force` es false, solo si aún no existe). Vale en la
## partida principal y en la rama (que lleva las suyas); nunca en la inducción.
func record_turn_start(n: int, force: bool = false, agent: String = "") -> void:
	var a := current if agent == "" else agent
	if _ctx_of(a) == CTX_TUTORIAL or n < 1:
		return
	var p := progress(a)
	var turns: Dictionary = p.get("turnos", {})
	if turns.has(str(n)) and not force:
		return
	var snap := make_snapshot(a, n)
	if turns.has(str(n)):
		snap["alcanzado"] = str((turns[str(n)] as Dictionary).get("alcanzado", snap["alcanzado"]))
	turns[str(n)] = snap
	p["turnos"] = turns
	save(a)


## Resultado del turno n cerrado (Available %, WW, incidencias, contactos, CSAT, despedido): va a su instantánea.
func record_turn_result(n: int, result: Dictionary, agent: String = "") -> void:
	var a := current if agent == "" else agent
	if _ctx_of(a) == CTX_TUTORIAL or n < 1:
		return
	var p := progress(a)
	var turns: Dictionary = p.get("turnos", {})
	if not turns.has(str(n)):
		turns[str(n)] = make_snapshot(a, n)
	var r := result.duplicate(true)
	r["cerrado"] = Time.get_datetime_string_from_system()
	(turns[str(n)] as Dictionary)["resultado"] = r
	p["turnos"] = turns
	save(a)


## Instantáneas de la partida PRINCIPAL del agente, ordenadas por turno (las que se pueden elegir).
func snapshots(agent: String = "") -> Array:
	var a := current if agent == "" else agent
	var p := main_progress(a)
	var turns: Dictionary = p.get("turnos", {})
	var out: Array = []
	for k in turns.keys():
		out.append(turns[k])
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.get("turno", 0)) < int(y.get("turno", 0)))
	return out


func snapshot(n: int, agent: String = "") -> Dictionary:
	var a := current if agent == "" else agent
	return ((main_progress(a).get("turnos", {}) as Dictionary).get(str(n), {}) as Dictionary)


## Progreso de la partida principal (aunque el agente esté en una rama o en la inducción).
func main_progress(agent: String = "") -> Dictionary:
	var a := current if agent == "" else agent
	if _ctx_of(a) == CTX_MAIN:
		return progress(a)
	var key := a + "|"
	if not _cache.has(key):
		var d := default_progress(a)
		d["dificultad"] = "normal"
		var parsed: Variant = _read_json(main_progress_path(a))
		var old_version := VERSION
		if parsed is Dictionary:
			old_version = int((parsed as Dictionary).get("version", 1))
			for k in (parsed as Dictionary).keys():
				d[k] = parsed[k]
		d["version"] = VERSION
		d["agente"] = a
		_normalize(d)
		if parsed is Dictionary and _migrate_v4(d, old_version):
			_write_json(main_progress_path(a), d)
		_cache[key] = d
	return _cache[key]


func _save_main(agent: String, d: Dictionary) -> void:
	if str(d.get("creada", "")) == "":
		d["creada"] = Time.get_datetime_string_from_system()
	d["actualizada"] = Time.get_datetime_string_from_system()
	_cache[agent + "|"] = d
	_write_json(main_progress_path(agent), d)


## Turno "frontera" de la partida principal: el siguiente que Continuar jugaría (primero sin cerrar, dentro de
## lo desbloqueado y habilitado). Los turnos ANTERIORES se rejuegan en rama; este es Continuar.
func frontier(agent: String = "") -> int:
	var a := current if agent == "" else agent
	var p := main_progress(a)
	var closed: Array = p.get("turnos_cerrados", [])
	var n := 1
	while closed.has(n) and n < 10:
		n += 1
	var mx := maxi(int(p.get("turno_desbloqueado", 1)), 1)
	while mx > 1 and not GameState.turno_available(mx):
		mx -= 1
	return mini(n, mx)


## Lista para la pantalla "Elegir turno": [{turno, alcanzado, saldo, resultado, actual, rama}] (solo turnos
## alcanzados en la partida principal y habilitados en esta versión).
func choosable_turns(agent: String = "") -> Array:
	var a := current if agent == "" else agent
	var fr := frontier(a)
	var out: Array = []
	for s in snapshots(a):
		var n := int((s as Dictionary).get("turno", 0))
		if n < 1 or n > fr or not GameState.turno_available(n):
			continue
		var e: Dictionary = (s as Dictionary).duplicate(true)
		e["actual"] = n == fr
		e["rama"] = n < fr
		out.append(e)
	return out


# --- Rama (rejugar un turno pasado) ------------------------------------------------------------

## Empieza una rama desde la instantánea del turno n (debe ser un turno alcanzado ANTERIOR a la frontera).
## La partida principal no se toca. `dificultad`/`modo` son los elegidos en el menú (-1 = los de la instantánea).
func start_branch(n: int, dificultad: int = -1, modo: int = -1, agent: String = "") -> bool:
	var a := current if agent == "" else agent
	var snap := snapshot(n, a)
	if snap.is_empty() or n >= frontier(a):
		return false
	if a != current:
		select(a)
	_remove_branch_files(a)
	var main := main_progress(a)
	var d := default_progress(a)
	for k in ["saldo", "turno_desbloqueado", "turnos_cerrados", "dificultad", "mode", "ww_total", "contadores", "memos"]:
		if snap.has(k):
			var v: Variant = snap[k]
			d[k] = v.duplicate(true) if (v is Array or v is Dictionary) else v
	d["turno_desbloqueado"] = int(snap.get("turno_desbloqueado", n))
	# Lo que se desbloquea para siempre viene de la partida principal (hoy), no de la instantánea.
	d["finales"] = (main.get("finales", []) as Array).duplicate()
	d["epilogos"] = (main.get("epilogos", []) as Array).duplicate()
	d["memos"] = _union(main.get("memos", []), d.get("memos", []))
	d["tooltips_vistos"] = (main.get("tooltips_vistos", []) as Array).duplicate()
	if dificultad >= 0:
		d["dificultad"] = Difficulty.IDS[clampi(dificultad, 0, Difficulty.IDS.size() - 1)]
	if modo >= 0:
		d["mode"] = modo
	var turns: Dictionary = {}
	for k in (main.get("turnos", {}) as Dictionary).keys():
		if int(k) <= n:
			turns[k] = (main["turnos"][k] as Dictionary).duplicate(true)
	if turns.has(str(n)):
		(turns[str(n)] as Dictionary).erase("resultado")
	d["turnos"] = turns
	d["rama_de"] = n
	context = CTX_BRANCH
	_cache[_key(a)] = d
	save(a)
	_write_json(branch_meta_path(a), {"turno": n, "iniciada": Time.get_datetime_string_from_system(), "agente": a})
	_apply_difficulty()
	return true


## Rama guardada en disco del agente (para "Continuar la rama"): {turno, iniciada} o {}.
func pending_branch(agent: String = "") -> Dictionary:
	var parsed: Variant = _read_json(branch_meta_path(current if agent == "" else agent))
	if parsed is Dictionary:
		(parsed as Dictionary)["turno"] = int((parsed as Dictionary).get("turno", 1))
		return parsed
	return {}


## Retoma la rama guardada (su checkpoint) del agente activo.
func resume_branch() -> bool:
	if pending_branch().is_empty():
		return false
	context = CTX_BRANCH
	_cache.erase(_key(current))
	_apply_difficulty()
	return true


## Termina la rama. keep = "Seguir desde aquí": la partida principal pasa a ser la rama (se reemplaza el
## progreso posterior: instantáneas de turnos más altos, checkpoint a medias). Si no, la rama se descarta.
## En los dos casos lo que se desbloquea para siempre (finales, epílogos, memos) queda en la principal.
func end_branch(keep: bool) -> void:
	var a := current
	if context != CTX_BRANCH and pending_branch(a).is_empty():
		return
	var was := context
	context = CTX_BRANCH
	var b: Dictionary = progress(a).duplicate(true)
	context = CTX_MAIN
	var main := main_progress(a).duplicate(true)
	var n := int(b.get("rama_de", int(pending_branch(a).get("turno", 0))))
	if keep:
		var nd := b.duplicate(true)
		nd.erase("rama_de")
		nd["finales"] = _union(main.get("finales", []), b.get("finales", []))
		nd["epilogos"] = _union(main.get("epilogos", []), b.get("epilogos", []))
		nd["memos"] = _union(main.get("memos", []), b.get("memos", []))
		nd["tooltips_vistos"] = _union(main.get("tooltips_vistos", []), b.get("tooltips_vistos", []))
		nd["creada"] = str(main.get("creada", ""))
		nd["seguido_desde"] = {"turno": n, "fecha": Time.get_datetime_string_from_system()}
		var mc := main_checkpoint_path(a)
		if FileAccess.file_exists(mc):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(mc))
		_save_main(a, nd)
	else:
		main["finales"] = _union(main.get("finales", []), b.get("finales", []))
		main["epilogos"] = _union(main.get("epilogos", []), b.get("epilogos", []))
		main["memos"] = _union(main.get("memos", []), b.get("memos", []))
		_save_main(a, main)
	_remove_branch_files(a)
	_cache.erase(a + "|" + CTX_BRANCH)
	if was != CTX_MAIN or context != CTX_MAIN:
		context = CTX_MAIN
	_apply_difficulty()


func _remove_branch_files(agent: String) -> void:
	var d := dir_of(agent) + "rama/"
	for f in ["progreso.json", "checkpoint.json", "rama.json"]:
		if FileAccess.file_exists(d + f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(d + f))
	_cache.erase(agent + "|" + CTX_BRANCH)


static func _union(a: Variant, b: Variant) -> Array:
	var out: Array = []
	for v in (a if a is Array else []):
		if not out.has(v):
			out.append(v)
	for v in (b if b is Array else []):
		if not out.has(v):
			out.append(v)
	return out


# --- Lo que se desbloquea para siempre (por agente) ------------------------------------------------

## Final visto: queda en la partida principal para siempre (también si se vio en una rama).
func unlock_ending(id: String, agent: String = "") -> void:
	_unlock_forever("finales", id, agent)


func unlock_epilogue(id: String, agent: String = "") -> void:
	_unlock_forever("epilogos", id, agent)


func unlock_memo(id: String, agent: String = "") -> void:
	_unlock_forever("memos", id, agent)


func _unlock_forever(field: String, id: String, agent: String) -> void:
	var a := current if agent == "" else agent
	if _ctx_of(a) == CTX_TUTORIAL:
		return
	var main := main_progress(a)
	var arr: Array = main.get(field, [])
	if not arr.has(id):
		arr.append(id)
		main[field] = arr
		_save_main(a, main)
	if _ctx_of(a) == CTX_BRANCH:
		var b := progress(a)
		var ba: Array = b.get(field, [])
		if not ba.has(id):
			ba.append(id)
			b[field] = ba
			save(a)


## Contador de elecciones / finales (el OM y los finales de T4-T10 lo usarán): va en las instantáneas.
func bump_counter(key: String, n: int = 1, agent: String = "") -> int:
	var a := current if agent == "" else agent
	var p := progress(a)
	var c: Dictionary = p.get("contadores", {})
	c[key] = int(c.get(key, 0)) + n
	p["contadores"] = c
	return int(c[key])


# --- Duración del turno (v0.3.1 Q1, D3/F21, contrato C14) ----------------------------------------------

const SHIFT_LENGTHS: Array[String] = ["corta", "normal", "larga"]


## Preset del reloj del agente ("corta" | "normal" | "larga"; por defecto "normal"). Vive en la partida PRINCIPAL
## (progreso.json, clave `duracion_turno`): la rama y la inducción usan el del agente.
func shift_length(agent: String = "") -> String:
	var a := current if agent == "" else agent
	var v := str(main_progress(a).get("duracion_turno", "normal"))
	return v if SHIFT_LENGTHS.has(v) else "normal"


## Cambia el preset del agente (Opciones → «Duración del turno»). Se escribe al disco solo si la partida existe
## (si no, queda en memoria y se guarda con el primer turno): elegirlo no crea una partida vacía.
func set_shift_length(id: String, agent: String = "") -> void:
	if not SHIFT_LENGTHS.has(id):
		return
	var a := current if agent == "" else agent
	var d := main_progress(a)
	d["duracion_turno"] = id
	if FileAccess.file_exists(main_progress_path(a)):
		_save_main(a, d)
	EventBus.settings_changed.emit("duracion_turno")


# --- Tooltips de primera vez (una vez por partida) --------------------------------------------------

func tooltip_seen(id: String) -> bool:
	return (progress().get("tooltips_vistos", []) as Array).has(id)


func mark_tooltip(id: String) -> void:
	var p := progress()
	var arr: Array = p.get("tooltips_vistos", [])
	if not arr.has(id):
		arr.append(id)
		p["tooltips_vistos"] = arr
		if exists(current) or _ctx_of(current) != CTX_MAIN:
			save(current)


# --- Migración v3 → v4 (instantáneas por turno) ------------------------------------------------------

## Una partida sin `turnos` recibe una instantánea por turno alcanzado (1..turno_desbloqueado). Del T1 se sabe
## todo (estado inicial); de los demás se usa el estado actual (saldo, cerrados hasta ese turno) marcado
## `migrado`. Devuelve true si cambió algo.
func _migrate_v4(d: Dictionary, old_version: int) -> bool:
	var turns: Dictionary = d.get("turnos", {}) if d.get("turnos") is Dictionary else {}
	if old_version >= 4 and not turns.is_empty():
		return false
	var unlocked := maxi(int(d.get("turno_desbloqueado", 1)), 1)
	var closed: Array = d.get("turnos_cerrados", [])
	var stamp := str(d.get("actualizada", "")) if str(d.get("actualizada", "")) != "" else Time.get_datetime_string_from_system()
	for n in range(1, unlocked + 1):
		if turns.has(str(n)):
			continue
		var cl: Array = []
		for c in closed:
			if int(c) < n:
				cl.append(int(c))
		var snap := {
			"turno": n, "alcanzado": stamp, "saldo": -1.0 if n == 1 else float(d.get("saldo", -1.0)),
			"turno_desbloqueado": n, "turnos_cerrados": cl, "dificultad": str(d.get("dificultad", "normal")),
			"mode": int(d.get("mode", 0)), "fatiga_base": fatigue_base_of(n), "ww_total": 0,
			"contadores": {}, "memos": [], "finales": [], "migrado": true,
		}
		if closed.has(n) or closed.has(float(n)):
			snap["resultado"] = {"migrado": true}
		turns[str(n)] = snap
	d["turnos"] = turns
	for k in ["epilogos", "memos", "tooltips_vistos"]:
		if not d.has(k):
			d[k] = []
	if not d.has("contadores"):
		d["contadores"] = {}
	if not d.has("ww_total"):
		d["ww_total"] = 0
	d["migrado_v4"] = Time.get_datetime_string_from_system()
	return true


# --- Migración de la v0.2 --------------------------------------------------------------------

## Pasa user://progreso.json y user://save_slot_1.json a la carpeta del agente guardado.
## Devuelve la lista de lo migrado (vacía si no había nada). Idempotente: los viejos quedan como .v02.bak.
func migrate_v02() -> Array[String]:
	var done: Array[String] = []
	var old_progress := legacy_dir + "progreso.json"
	var old_cp := legacy_dir + "save_slot_1.json"
	var prog: Variant = _read_json(old_progress)
	if prog is Dictionary:
		var a := agent_from(str((prog as Dictionary).get("agent", "Jiroshi")))
		if a == "":
			a = "Jiroshi"
		var d := progress(a)
		for k in ["turno_desbloqueado", "turnos_cerrados", "saldo", "mode"]:
			if (prog as Dictionary).has(k):
				d[k] = prog[k]
		d["migrado_de"] = "v0.2"
		_normalize(d)
		_migrate_v4(d, 3)  # y sus instantáneas por turno (P6b)
		save(a)
		_backup(old_progress)
		done.append("progreso → " + a)
	var cp: Variant = _read_json(old_cp)
	if cp is Dictionary:
		var gs: Dictionary = (cp as Dictionary).get("game_state", {})
		var a2 := agent_from(str(gs.get("agent", "Jiroshi")))
		if a2 == "":
			a2 = "Jiroshi"
		var mig := Metrics.migrate_save_dict((cp as Dictionary).get("metrics", {}))
		cp["metrics"] = mig
		cp["version"] = VERSION
		cp["agente"] = a2
		cp["turno"] = int(gs.get("turno", 1))
		write_checkpoint(a2, cp)
		if not FileAccess.file_exists(progress_path(a2)):
			save(a2)
		_backup(old_cp)
		done.append("checkpoint → " + a2)
	if not done.is_empty():
		print("[SaveSlots] migración v0.2: ", ", ".join(done))
	return done


func _backup(path: String) -> void:
	var g := ProjectSettings.globalize_path(path)
	DirAccess.rename_absolute(g, g + ".v02.bak")


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


func _write_json(path: String, d: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("SaveSlots: no se pudo escribir %s" % path)
		return
	f.store_string(JSON.stringify(d, "\t"))


## Escenarios de prueba: usa otra carpeta (no toca las partidas del jugador) y vacía la caché.
func use_sandbox(dir: String) -> void:
	root = dir.path_join("partidas") + "/"
	legacy_dir = dir + "/"
	context = CTX_MAIN
	_cache.clear()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
