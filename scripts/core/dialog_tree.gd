class_name DialogTree
extends RefCounted
## Motor de los árboles de diálogo de llamadas y chats (formato arbol_v1, PLAN §5). Lógica pura, sin UI ni
## reloj: ContactManager lo maneja (reloj 6x + t_juego, hold, timeout de chat) y Kardex lo dibuja.
##
## Reglas:
## - El ánimo parte de `animo_inicial` (−100..100) y suma el `animo` de cada opción. Si baja de −50 en
##   cualquier nodo el cliente cuelga (salta al primer final `molesto`).
## - `requiere`: tipos de opción ya usados o acciones ya completadas; si falta alguno → `si_falta`.
## - `accion` (salvo `hold`): la conversación espera el resultado de la app (`action_done`) o su cancelación
##   (`action_cancel`, −10 de ánimo y vuelve a `sig`). `si_portal` del nodo destino elige el siguiente nodo según
##   lo que mostró el portal ("pod_ok" | "pod_no").
## - Las opciones con `qa` dejan una marca (Haime puede llamarte por ella aunque el cliente termine satisfecho).

const HANGUP := -50.0
const CANCEL_PENALTY := -10.0

var contact: Dictionary = {}
var node_id: String = ""
var final_id: String = ""
var animo: float = 0.0
var used: Array[String] = []  # tipos de opción usados + acciones completadas
var qa_marks: Array[String] = []
var history: Array = []  # [{quien: "cliente"|"yo", texto: {es,en}}]
var choices: Array[String] = []  # "nodo.opcion" en orden
var pending: Dictionary = {}  # opción con acción esperando resultado de una app
var hung_up: bool = false


func start(c: Dictionary) -> void:
	contact = c
	animo = float(c.get("animo_inicial", 0.0))
	used.clear()
	qa_marks.clear()
	history.clear()
	choices.clear()
	pending = {}
	final_id = ""
	hung_up = false
	_go(str(c.get("inicio", "inicio")))


func ended() -> bool:
	return final_id != ""


func nodes() -> Dictionary:
	return contact.get("nodos", {})


func finals() -> Dictionary:
	return contact.get("finales", {})


func node() -> Dictionary:
	return nodes().get(node_id, {})


func final() -> Dictionary:
	return finals().get(final_id, {})


func outcome() -> String:
	return str(final().get("resultado", "neutral"))


func csat() -> int:
	return int(final().get("csat", 3))


func options() -> Array:
	return node().get("opciones", [])


## Línea actual del cliente ({es,en}): la del nodo o la del final.
func client_line() -> Dictionary:
	if ended():
		return final().get("cliente", {})
	return node().get("cliente", {})


func waiting_action() -> bool:
	return not pending.is_empty()


func pending_action() -> String:
	return str(pending.get("accion", ""))


## Indicador cualitativo del ánimo (Kardex): "tranquilo" | "tenso" | "a_punto".
func mood() -> String:
	if animo >= 10.0:
		return "tranquilo"
	if animo > -30.0:
		return "tenso"
	return "a_punto"


## Elige la opción i. Devuelve {ok, t_juego, accion, muerte, sig, final}.
## Si la opción tiene acción (no hold), el árbol queda esperando `action_done` / `action_cancel`.
func choose(i: int) -> Dictionary:
	var opts := options()
	if ended() or waiting_action() or i < 0 or i >= opts.size():
		return {"ok": false}
	var o: Dictionary = opts[i]
	choices.append("%s.%s" % [node_id, str(o.get("id", i))])
	history.append({"quien": "yo", "texto": {"es": str(o.get("es", "")), "en": str(o.get("en", ""))}})
	animo = clampf(animo + float(o.get("animo", 0.0)), -100.0, 100.0)
	var tipo := str(o.get("tipo", ""))
	if tipo != "" and not used.has(tipo):
		used.append(tipo)
	if o.has("qa"):
		qa_marks.append(str(o.get("qa")))
	var res := {"ok": true, "t_juego": float(o.get("t_juego", 0.0)), "accion": str(o.get("accion", "")), "muerte": str(o.get("muerte_al_enviar", "")), "evento": str(o.get("evento", ""))}
	var accion := str(o.get("accion", ""))
	if accion != "" and accion != "hold":
		pending = o
		return res
	if accion == "hold" and not used.has("hold"):
		used.append("hold")
	_advance(o, "")
	res["final"] = final_id
	res["sig"] = node_id
	return res


## La app terminó la acción pendiente (portal_pod → "pod_ok"/"pod_no"; portal_contacto → "ok").
func action_done(result: String = "ok") -> void:
	if pending.is_empty():
		return
	var o := pending
	pending = {}
	var a := str(o.get("accion", ""))
	if a != "" and not used.has(a):
		used.append(a)
	_advance(o, result)


## Se canceló la acción (p. ej. el correo a Vitzo no se envió): −10 de ánimo y vuelve a `sig`.
func action_cancel() -> void:
	if pending.is_empty():
		return
	var o := pending
	pending = {}
	animo = clampf(animo + CANCEL_PENALTY, -100.0, 100.0)
	_advance(o, "")


## Fuerza un final (timeout del chat, pararse sin hold, cliente perdido).
func force_final(fid: String) -> void:
	if finals().has(fid):
		final_id = fid
	else:
		final_id = first_final("molesto")
	pending = {}
	history.append({"quien": "cliente", "texto": client_line()})


func first_final(result: String) -> String:
	for k in finals().keys():
		if str((finals()[k] as Dictionary).get("resultado", "")) == result:
			return str(k)
	var ks := finals().keys()
	return str(ks[0]) if not ks.is_empty() else ""


func _advance(o: Dictionary, portal_result: String) -> void:
	var target := str(o.get("sig", ""))
	var req: Array = o.get("requiere", [])
	for r in req:
		if not used.has(str(r)):
			target = str(o.get("si_falta", target))
			break
	if animo < HANGUP:
		hung_up = true
		# Cuelga: si la opción ya llevaba a un final molesto propio (p. ej. fin_molesto_qa), ese; si no, el primero.
		if not (finals().has(target) and str((finals()[target] as Dictionary).get("resultado", "")) == "molesto"):
			target = first_final("molesto")
	elif portal_result != "" and nodes().has(target):
		var sp: Dictionary = (nodes()[target] as Dictionary).get("si_portal", {})
		if sp.has(portal_result):
			target = str(sp[portal_result])
	_go(target)


func _go(target: String) -> void:
	if finals().has(target):
		final_id = target
		history.append({"quien": "cliente", "texto": client_line()})
		return
	if not nodes().has(target):
		final_id = first_final("neutral")
		history.append({"quien": "cliente", "texto": client_line()})
		return
	node_id = target
	history.append({"quien": "cliente", "texto": client_line()})


## Enumeración de caminos para las pruebas (escenario arbol:<id>): lista de secuencias de elecciones
## [{i, accion_resultado}] que llegan a un final. Las acciones de correo se exploran como "cancelar" (las de
## "enviar" mueren antes de llegar a un final). Evita bucles: no repite un (nodo, opción) en el mismo camino.
static func enumerate_paths(c: Dictionary, max_paths: int = 400) -> Array:
	var out: Array = []
	_walk(c, [], out, max_paths)
	return out


static func _walk(c: Dictionary, prefix: Array, out: Array, max_paths: int) -> void:
	if out.size() >= max_paths:
		return
	var t := DialogTree.new()
	t.start(c)
	var portal: Dictionary = c.get("portal", {})
	for step in prefix:
		t.choose(int(step["i"]))
		if t.waiting_action():
			if str(step.get("r", "")) == "cancel":
				t.action_cancel()
			else:
				t.action_done(str(step.get("r", "ok")))
	if t.ended():
		out.append(prefix.duplicate())
		return
	var seen := {}
	for s in prefix:
		seen[str(s.get("k", ""))] = int(seen.get(str(s.get("k", "")), 0)) + 1
	var opts := t.options()
	for i in opts.size():
		var o: Dictionary = opts[i]
		var k := "%s.%d" % [t.node_id, i]
		if int(seen.get(k, 0)) >= 1:
			continue
		var a := str(o.get("accion", ""))
		var results: Array = ["ok"]
		if a.begins_with("correo"):
			results = ["cancel"]
		elif a == "portal_pod":
			# El portal del contacto decide; las pruebas recorren también la otra rama (si_portal).
			results = ["pod_ok", "pod_no"] if bool(portal.get("pod", true)) else ["pod_no", "pod_ok"]
		for r in results:
			var p := prefix.duplicate()
			p.append({"i": i, "r": r, "k": k})
			_walk(c, p, out, max_paths)


## Simula un camino (de enumerate_paths) y devuelve {final, resultado, csat, qa, correo, acciones}.
static func simulate(c: Dictionary, path: Array) -> Dictionary:
	var t := DialogTree.new()
	t.start(c)
	var correo := false
	var acciones: Array[String] = []
	for step in path:
		var o: Dictionary = t.options()[int(step["i"])] if int(step["i"]) < t.options().size() else {}
		var a := str(o.get("accion", ""))
		if a != "":
			acciones.append(a)
		t.choose(int(step["i"]))
		if t.waiting_action():
			if str(step.get("r", "")) == "cancel":
				correo = true
				t.action_cancel()
			else:
				t.action_done(str(step.get("r", "ok")))
	return {"final": t.final_id, "resultado": t.outcome() if t.ended() else "", "csat": t.csat() if t.ended() else 0, "qa": t.qa_marks.duplicate(), "correo": correo, "acciones": acciones}


## Mejor camino para el bot listo: final satisfecho, sin marcas de QA ni correos, coherente con lo que mostrará
## el portal del contacto; a igualdad, el más corto. mode "peor" = el bot torpe (trampas, molesto).
static func best_path(c: Dictionary, mode: String = "mejor") -> Array:
	var pod := bool((c.get("portal", {}) as Dictionary).get("pod", true))
	var best: Array = []
	var best_score := -INF
	for p in enumerate_paths(c):
		var ok := true
		for s in p:
			if str(s.get("r", "")) == ("pod_no" if pod else "pod_ok"):
				ok = false
		if not ok:
			continue
		var sim := simulate(c, p)
		var score := 0.0
		match str(sim.get("resultado", "")):
			"satisfecho": score = 100.0
			"neutral": score = 40.0
			"molesto": score = 0.0
		score -= 15.0 * (sim.get("qa", []) as Array).size() + (30.0 if bool(sim.get("correo", false)) else 0.0) + p.size()
		if mode == "peor":
			score = -score
		if score > best_score:
			best_score = score
			best = p
	return best
