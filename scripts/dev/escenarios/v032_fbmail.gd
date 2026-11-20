## Sin class_name: lo carga el runner de escenarios.
extends RefCounted
## v0.3.2 · feedback de Joan sobre los correos de BO («los correos de Vitzo y otros que hago bien salen como mal
## resueltos»). Cada correo de cada turno se juega por la interfaz REAL (dev/manos_pc.gd: clics de ratón sobre los
## mismos controles que usa el jugador, teclas por la ventana), no llamando a ContactManager:
##   fbm_correo:<id>   el correo <id>: el camino correcto y todas las variantes correctas que haría una persona
##                     (otro orden, tipificar antes, clics de más, portal primero, minúsculas, salir y volver, clics
##                     lentos, tras morir y reconectar…) → «Caso cerrado» (bo_ok); y sus variantes MAL hechas →
##                     «Caso cerrado con errores» (bo_miss) con el motivo exacto.
##   fbm_correos       los seis correos (T1-T3).
##   fbm_kyc           los KYC de los tres turnos y los de relleno por Identa.
##   fbm_dificultades  el camino correcto de cada correo en Fácil / Normal / Difícil y con los cinco agentes: la nota
##                     no cambia.
##   fbm_trampa        correo a Vitzo en los tres casos de Vitzo → muerte (las reglas de muerte no cambian).
##   fbm_pasos         punto 8 de Joan («¿por qué los pasos me piden adjuntar si el caso no es de Vitzo?»): la barra
##                     de pasos, la guía del primer correo, la casilla de adjuntar y el panel «Siguiente paso» de
##                     cada correo, paso a paso, en ES y EN; `sin_pod` solo existe donde se pidió un POD.
##   fbm_textos        el manual, el minitraining del Mentor, las pistas y las líneas de Haime dicen la misma regla.
## Con `--fbm-tabla` cada jugada imprime una línea «[fbm] …» (de ahí sale qa_fb_mail/CORREOS.md).

const Manos := preload("res://scripts/dev/manos_pc.gd")
const MAILS: Array[String] = ["t1_correo_pod", "vz_status", "t2_correo_reversal", "vz_pod", "t3_correo_status", "vz_reversal"]
const AGENTS: Array[String] = ["Jiroshi", "Marko", "Llauri", "Ttoom", "Juan"]


func escenarios() -> Array[String]:
	return ["fbm_correo:", "fbm_correos", "fbm_kyc", "fbm_dificultades", "fbm_trampa", "fbm_pasos", "fbm_textos"]


func run(id: String, arg: String, t: Node) -> void:
	match id:
		"fbm_correo": await _mail(t, arg)
		"fbm_correos":
			for cid in MAILS:
				await _mail(t, cid)
		"fbm_kyc": await _kyc(t)
		"fbm_dificultades": await _difficulties(t)
		"fbm_trampa": await _trap(t)
		"fbm_pasos": await _steps(t)
		"fbm_textos": await _texts(t)


# --- datos -------------------------------------------------------------------------------------------------------------

static func all_cases() -> Array:
	var out: Array = []
	var bo := DataLoader.dict("casos_bo")
	for tn in ["1", "2", "3"]:
		for c in (bo.get("turnos", {}) as Dictionary).get(tn, []):
			var d: Dictionary = (c as Dictionary).duplicate(true)
			d["_turno"] = int(tn)
			out.append(d)
	for c in bo.get("relleno_kyc", []):
		var d: Dictionary = (c as Dictionary).duplicate(true)
		d["_turno"] = 3
		out.append(d)
	return out


static func case_by_id(cid: String) -> Dictionary:
	for c in all_cases():
		if str(c.get("id", "")) == cid:
			return c
	return {}


static func tip_text(id: String) -> String:
	for tp in DataLoader.dict("casos_bo").get("tipificaciones", []):
		if str(tp.get("id", "")) == id:
			return Loc.pick(tp)
	return id


func _cm(t: Node) -> ContactManager:
	return t.main.get("contacts") as ContactManager


# --- las jugadas de cada correo -------------------------------------------------------------------------------------------

## Pasos del camino correcto de un caso de correo, en trozos que las variantes recombinan.
func _parts(c: Dictionary) -> Dictionary:
	var corr: Dictionary = c.get("correcto", {})
	var portal: Array = []
	for p in corr.get("portal", []):
		match str(p):
			"buscar": portal.append("portal")
			"pod": portal.append("pod_descargar")
			"reversal": portal.append("reversal")
			"contacto": portal.append("contacto")
	var dest := str(corr.get("destinatario", ""))
	var mail_head: Array = []
	var copies: Array = []
	var lists: Array = []
	var send: Array = []
	var attach: Array = []
	if dest != "":
		mail_head = ["dest:" + dest, "tpl:" + str(corr.get("plantilla", ""))]
		copies = ["copiar:id", "copiar:monto", "copiar:fecha"]
		for f in CasoBO.FIELDS:
			lists.append("campo:%s:%s" % [f, str((corr.get("campos", {}) as Dictionary).get(f, ""))])
		send = ["enviar"]
		if bool(corr.get("adjunto_pod", false)):
			attach = ["pod_adjuntar"]
	return {"portal": portal, "head": mail_head, "copies": copies, "lists": lists, "attach": attach, "send": send,
		"tip": ["tip:" + str(corr.get("tipificacion", ""))], "dest": dest, "vitzo": str(c.get("vitzo", "")) != ""}


## Variantes CORRECTAS (todas deben dar bo_ok) y MAL hechas (bo_miss con su motivo) de un correo.
func _variants(c: Dictionary) -> Array:
	var p := _parts(c)
	var cid := str(c.get("id", ""))
	var tx := str(c.get("tx", ""))
	var opts: Dictionary = c.get("opciones_campos", {})
	var corr: Dictionary = c.get("correcto", {})
	var ok: Array = []
	var bad: Array = []
	var A: Array = ["aceptar"]
	var K: Array = ["kardex"]
	var close: Array = ["cerrar"]
	var mail: Array = p["head"] + p["copies"] + p["attach"] + p["send"]
	var has_mail := str(p["dest"]) != ""
	ok.append({"n": "camino del manual", "s": A + K + p["portal"] + mail + p["tip"] + close})
	ok.append({"n": "todo con clics: Aceptar en Fonex, barra de tareas, «Ver en Kardex», campos de las listas",
		"s": ["aceptar_boton", "kardex_boton"] + _clicky(p["portal"]) + ["app_clic:correo"] + p["head"] + p["lists"] + p["attach"] + p["send"] + p["tip"] + close})
	ok.append({"n": "Kardex tecleado en minúsculas y con espacios", "s": A + ["kardex_teclado:  %s " % tx.to_lower()] + p["portal"] + mail + p["tip"] + close})
	ok.append({"n": "Kardex tecleado + botón Buscar", "s": A + ["kardex_teclado_boton:" + tx] + p["portal"] + mail + p["tip"] + close})
	ok.append({"n": "tipificar antes de enviar", "s": A + K + p["portal"] + p["tip"] + mail + close})
	ok.append({"n": "tipificar lo primero (antes de Kardex)", "s": A + p["tip"] + K + p["portal"] + mail + close})
	ok.append({"n": "clics lentos (0,5 s apretado)", "s": ["lento"] + A + K + p["portal"] + mail + p["tip"] + close})
	ok.append({"n": "clic normal de ratón (0,12 s) en «Aceptar» de Fonex y en todo lo demás", "s": ["humano", "aceptar_boton", "kardex_boton"] + _clicky(p["portal"]) + ["app_clic:correo"] + mail + p["tip"] + close})
	ok.append({"n": "salir y volver (levantarse y sentarse) a mitad del caso", "s": A + K + ["pararse"] + p["portal"] + (p["head"] + ["pararse"] + p["copies"] + p["attach"] + p["send"] if has_mail else []) + p["tip"] + ["alejar"] + close})
	ok.append({"n": "clics de más inofensivos (Campus, Identa, Ezlaki, repetir Kardex, cerrar y abrir listas)",
		"s": A + ["app:campus", "app:identa"] + K + ["kardex", "app_clic:campus", "ezlaki"] + p["portal"] + (p["portal"] if not p["portal"].is_empty() else []).slice(0, 1) + mail + p["tip"] + p["tip"] + ["app:kardex", "app:correo"] + close})
	ok.append({"n": "tras morir y reconectar a mitad del caso (el correo vuelve y se hace de nuevo)",
		"s": A + K + p["portal"].slice(0, 1) + ["morir"] + A + K + p["portal"] + mail + p["tip"] + close})
	ok.append({"n": "buscar primero un KP parecido en Kardex (no existe) y luego el bueno", "s": A + ["kardex_teclado:" + str((opts.get("id", ["", ""]) as Array)[1])] + K + p["portal"] + mail + p["tip"] + close})
	if has_mail:
		ok.append({"n": "plantilla y campos antes que el destinatario", "s": A + K + p["portal"] + [p["head"][1]] + p["copies"] + [p["head"][0]] + p["attach"] + p["send"] + p["tip"] + close})
		ok.append({"n": "campos marcados (>) y copiados en otro orden", "s": A + K + p["portal"] + p["head"] + ["marcar:fecha", "copiar:fecha", "marcar:monto", "copiar:monto", "marcar:id", "copiar:id"] + p["attach"] + p["send"] + p["tip"] + close})
		ok.append({"n": "copiar de Kardex en otro orden sin marcar el campo (monto, fecha, n.º)", "s": A + K + p["portal"] + p["head"] + ["copiar:monto", "copiar:fecha", "copiar:id"] + p["attach"] + p["send"] + p["tip"] + close})
		ok.append({"n": "copiar solo monto y fecha de Kardex; el n.º, de la lista", "s": A + K + p["portal"] + p["head"] + [p["lists"][0], "copiar:monto", "copiar:fecha"] + p["attach"] + p["send"] + p["tip"] + close})
		ok.append({"n": "equivocarse y corregir antes de enviar (destinatario, plantilla y un campo)",
			"s": A + K + p["portal"] + ["dest:" + _other_dest(str(p["dest"])), "tpl:" + _other_tpl(str(corr.get("plantilla", ""))), "campo:monto:" + _wrong(opts, "monto", corr)] + p["head"] + ["copiar:id", "marcar:monto", "copiar:monto", "copiar:fecha"] + p["attach"] + p["send"] + p["tip"] + close})
		ok.append({"n": "doble clic en cada valor de Kardex", "s": A + K + p["portal"] + p["head"] + ["copiar2:id", "copiar2:monto", "copiar2:fecha"] + p["attach"] + p["send"] + p["tip"] + close})
		ok.append({"n": "elegir el n.º de la lista y luego clic en n.º, monto y fecha de Kardex", "s": A + K + p["portal"] + p["head"] + [p["lists"][0]] + p["copies"] + p["attach"] + p["send"] + p["tip"] + close})
		if str(p["dest"]) != "Cliente":
			ok.append({"n": "además un correo de cortesía al cliente (Status)", "s": A + K + p["portal"] + mail + ["dest:Cliente", "tpl:Status", "enviar"] + p["tip"] + close})
		ok.append({"n": "deshacer con Retroceso y rehacer", "s": A + K + p["portal"] + p["head"] + p["copies"] + ["undo", "undo", "undo", "undo", "undo"] + mail + p["tip"] + close})
		ok.append({"n": "enviar, tipificar mal, corregir la tipificación y cerrar", "s": A + K + p["portal"] + mail + ["tip:sin_accion"] + p["tip"] + close})
	if bool(p["vitzo"]):
		ok.append({"n": "Portal ANTES que Kardex", "s": A + p["portal"] + K + mail + p["tip"] + close})
		ok.append({"n": "Portal tecleado en minúsculas + Intro", "s": A + K + ["portal_teclado: %s" % tx.to_lower()] + p["portal"].slice(1) + mail + p["tip"] + close})
		ok.append({"n": "Portal: el KP ya escrito al abrir + botón Buscar", "s": A + K + ["portal_prellenado"] + p["portal"].slice(1) + mail + p["tip"] + close})
		ok.append({"n": "Portal buscado dos veces y vuelta a Correo entre medias", "s": A + K + p["portal"].slice(0, 1) + ["app:correo"] + p["portal"] + mail + p["tip"] + close})
		ok.append({"n": "buscar primero un KP parecido en el Portal (sin resultados) y luego el bueno", "s": A + K + ["portal_teclado:" + str((opts.get("id", ["", ""]) as Array)[1])] + p["portal"] + mail + p["tip"] + close})
		if has_mail and p["attach"].is_empty():
			ok.append({"n": "responder primero y mirar el Portal después", "s": A + K + p["head"] + p["copies"] + ["enviar"] + p["portal"] + p["tip"] + close})
		elif has_mail:
			ok.append({"n": "enviar sin el POD, darse cuenta, adjuntar y reenviar", "s": A + K + p["head"] + p["copies"] + ["enviar"] + p["portal"] + p["attach"] + ["enviar"] + p["tip"] + close})
		if cid != "vz_reversal":
			ok.append({"n": "además pulsa «Contacto partner» en el Portal", "s": A + K + p["portal"] + ["contacto"] + mail + p["tip"] + close})
	match cid:
		"t1_correo_pod":
			ok.append({"n": "plantilla «POD request» (pedir el POD al partner)", "s": A + K + ["dest:Banco Andino", "tpl:POD request"] + p["copies"] + p["send"] + p["tip"] + close})
			ok.append({"n": "mira el Portal Vitzo por si acaso (la operación no existe ahí)", "s": A + K + ["portal"] + mail + p["tip"] + close})
			bad.append({"n": "monto del correo del cliente (1.205) en vez del de Kardex", "why": "correo_campo_monto", "s": A + K + p["head"] + ["copiar:id", "campo:monto:1.205,00 KP", "copiar:fecha"] + p["send"] + p["tip"] + close})
			bad.append({"n": "cerrar sin enviar nada", "why": "sin_enviar", "s": A + K + p["tip"] + close})
			bad.append({"n": "copiar el monto de la operación parecida (fila de abajo)", "why": "correo_campo_monto", "s": A + K + p["head"] + ["copiar:id", "copiar:monto:1", "copiar:fecha"] + p["send"] + p["tip"] + close})
		"vz_status":
			ok.append({"n": "además descarga el POD y lo adjunta a la respuesta", "s": A + K + p["portal"] + ["pod_descargar", "pod_adjuntar"] + mail + p["tip"] + close})
			bad.append({"n": "responder al cliente sin entrar al Portal Vitzo", "why": "falta_portal_buscar", "s": A + K + mail + p["tip"] + close})
			bad.append({"n": "tipificar «Status solicitado al partner»", "why": "tipificacion", "s": A + K + p["portal"] + mail + ["tip:status_partner"] + close})
		"t2_correo_reversal":
			bad.append({"n": "destinatario equivocado (Banco Andino)", "why": "destinatario_equivocado", "s": A + K + ["dest:Banco Andino", "tpl:Reversal"] + p["copies"] + p["send"] + p["tip"] + close})
			bad.append({"n": "plantilla equivocada (Status)", "why": "correo_plantilla", "s": A + K + ["dest:Caja Mirador", "tpl:Status"] + p["copies"] + p["send"] + p["tip"] + close})
		"vz_pod":
			ok.append({"n": "adjuntar con la casilla del Correo (no con el botón del Portal)", "s": A + K + p["portal"] + p["head"] + p["copies"] + ["adjuntar"] + p["send"] + p["tip"] + close})
			ok.append({"n": "adjuntar en el Portal, desmarcar y volver a marcar la casilla del Correo", "s": A + K + p["portal"] + ["pod_adjuntar"] + p["head"] + p["copies"] + ["adjuntar", "adjuntar"] + p["send"] + p["tip"] + close})
			ok.append({"n": "descargar el POD dos veces y adjuntar dos veces en el Portal", "s": A + K + p["portal"] + ["pod_descargar", "pod_adjuntar", "pod_adjuntar"] + p["head"] + p["copies"] + p["send"] + p["tip"] + close})
			bad.append({"n": "responder al banco sin adjuntar el POD", "why": "sin_pod", "s": A + K + p["portal"] + p["head"] + p["copies"] + p["send"] + p["tip"] + close})
			bad.append({"n": "tipificar «POD solicitado al partner»", "why": "tipificacion", "s": A + K + p["portal"] + mail + ["tip:pod_solicitado"] + close})
			bad.append({"n": "responder al banco con «POD request» (pedirle a él el POD)", "why": "correo_plantilla", "s": A + K + p["portal"] + ["dest:Banco Andino", "tpl:POD request"] + p["copies"] + p["attach"] + p["send"] + p["tip"] + close})
		"t3_correo_status":
			bad.append({"n": "tipificar «Status informado al cliente»", "why": "tipificacion", "s": A + K + mail + ["tip:status_informado"] + close})
			bad.append({"n": "fecha al revés (11/09)", "why": "correo_campo_fecha", "s": A + K + p["head"] + ["copiar:id", "copiar:monto", "campo:fecha:11/09"] + p["send"] + p["tip"] + close})
		"vz_reversal":
			ok.append({"n": "además responde al cliente por correo (Status, datos de Kardex)", "s": A + K + p["portal"] + ["dest:Cliente", "tpl:Status", "copiar:id", "copiar:monto", "copiar:fecha", "enviar"] + p["tip"] + close})
			ok.append({"n": "además pulsa «Contacto partner» en el Portal", "s": A + K + p["portal"] + ["contacto"] + p["tip"] + close})
			ok.append({"n": "pulsa el aviso del Portal (abre un correo a Vitzo) y NO lo envía", "s": A + K + ["portal", "aviso", "app:portal", "reversal"] + p["tip"] + close})
			bad.append({"n": "buscar en el Portal pero no registrar el reversal", "why": "falta_portal_reversal", "s": A + K + ["portal"] + p["tip"] + close})
			bad.append({"n": "pedir el reversal por correo a un banco", "why": "correo_innecesario", "s": A + K + p["portal"] + ["dest:Banco Andino", "tpl:Reversal", "copiar:id", "copiar:monto", "copiar:fecha", "enviar"] + p["tip"] + close})
			bad.append({"n": "tipificar «Reversal solicitado al partner»", "why": "tipificacion", "s": A + K + p["portal"] + ["tip:reversal_solicitado"] + close})
	return [ok, bad]


## Los pasos del portal, llegando a la app con un clic en la barra de tareas.
func _clicky(portal: Array) -> Array:
	if portal.is_empty():
		return []
	return ["app_clic:portal"] + portal


func _other_dest(d: String) -> String:
	return "Caja Mirador" if d != "Caja Mirador" else "RemesaYa"


func _other_tpl(tpl: String) -> String:
	return "Reversal" if tpl != "Reversal" else "Status"


func _wrong(opts: Dictionary, f: String, corr: Dictionary) -> String:
	for v in opts.get(f, []):
		if str(v) != str((corr.get("campos", {}) as Dictionary).get(f, "")):
			return str(v)
	return ""


# --- motor: abrir un turno, ofrecer el caso y hacer los pasos con las manos -----------------------------------------------

func _seat(t: Node) -> void:
	var b: Building = t.building()
	var fl := b.floor_node as FloorBase
	var seat := fl.seat_by_id("C-14") if fl != null else null
	if seat != null and not t.player().seated:
		t.player().sit_at(seat, "C-14")
	await t.frames(3)


func _play(t: Node, c: Dictionary, steps: Array, dif: int = 1, agent: String = "Jiroshi") -> Dictionary:
	await t.start_shift(agent, int(c.get("_turno", 1)), 0, dif)
	await t.login_at_seat()
	var cm := _cm(t)
	var m = Manos.new()
	var res := {"outcome": "", "qa": [], "fails": [], "deaths": [], "msg": "", "trace": [], "steps_done": 0}
	if not m.setup(t.main):
		res["fails"] = ["no hay PC"]
		return res
	# La vista que ve Joan: 16:9 (el alto de las pantallas acercadas depende de la proporción, no del tamaño).
	(m.ws as Node).set("layout_area_override", Vector2(1280, 720))
	var outcomes: Array = t.spy("contact_outcome")
	var deaths: Array = t.spy("death_requested")
	var msgs: Array = t.spy("show_message")
	var cid := str(c.get("id", ""))
	# El correo entra «a su hora» y esa hora es ahora: así, si mueres a mitad, vuelve enseguida (un guion vuelve a su
	# hora) y no hay que saltar el reloj (el lunch, el recordatorio de Vitzo y Haime no se meten en la prueba).
	var offered := c.duplicate(true)
	for sc in cm._schedule:
		if str((sc as Dictionary).get("id", "")) == cid:
			(sc as Dictionary)["hora_juego"] = "-9:00"  # ContactManager.clock_of: ya pasó (el turno empieza antes de medianoche)
		elif not cm._served.has(str((sc as Dictionary).get("id", ""))):
			cm._served.append(str((sc as Dictionary).get("id", "")))  # nada más del guion suena durante la prueba
	cm.phase = ContactManager.Phase.IDLE
	cm._offer(offered)
	await t.frames(3)
	for st in steps:
		var okk: bool = await _step(t, m, cm, c, str(st))
		if not okk:
			break
		res["steps_done"] = int(res["steps_done"]) + 1
	await t.frames(4)
	for o in outcomes:
		if str((o[0] as Dictionary).get("id", "")) == cid:
			res["outcome"] = str(o[1])
			res["qa"] = ((o[0] as Dictionary).get("_qa", []) as Array).duplicate()
	for d in deaths:
		(res["deaths"] as Array).append(str(d[0]))
	if not msgs.is_empty():
		res["msg"] = str(msgs[msgs.size() - 1][0])
	res["fails"] = m.fails.duplicate()
	res["trace"] = m.trace.duplicate()
	(m.ws as Node).set("layout_area_override", Vector2.ZERO)
	return res


func _step(t: Node, m: Object, cm: ContactManager, c: Dictionary, st: String) -> bool:
	var k := st.get_slice(":", 0)
	var a := st.substr(k.length() + 1) if st.contains(":") else ""
	match k:
		"aviso":
			var bn: Button = m.desk.portal._banner
			if not await m.click(bn, "aviso del Portal"):
				return false
			await t.frames(2)
			return true
		"undo":
			await m.app("correo")
			await m.key(KEY_BACKSPACE)
			return true
		"alejar":
			# [E] con la vista acercada la aleja (el paso siguiente la vuelve a acercar con su tecla, como el jugador).
			if bool(m.ws.get("zoomed")):
				for pressed in [true, false]:
					var e := InputEventAction.new()
					e.action = "interact"
					e.pressed = pressed
					m._send(e)
				await t.frames(3)
			return true
		"lento":
			m.hold_ms = 500
			return true
		"humano":
			m.hold_ms = 120  # lo que dura un clic normal de ratón
			return true
		"rapido":
			m.hold_ms = 0
			return true
		"ezlaki":
			# Un clic en la otra pantalla (la lista de canales de Ezlaki) y vuelta.
			var ez: Control = m.ws.get("ezlak")
			await m.click_at("right", ez.get_global_rect().position + Vector2(60, 60))
			await t.frames(2)
			return true
		"pararse":
			t.player().stand_up()
			await t.frames(6)
			await _seat(t)
			return true
		"espera":
			await t.seconds(float(a))
			return true
		"morir":
			await t.die("abandono", "", "shero")
			await t.wait_death_shown(30.0)
			await t.reconnect()
			await t.frames(4)
			await _seat(t)
			if Metrics.aux != Metrics.Aux.AVAILABLE:
				Metrics.set_aux(Metrics.Aux.AVAILABLE)
			var cid := str(c.get("id", ""))
			var back: bool = await t.until(func() -> bool: return cm.phase == ContactManager.Phase.OFFERING and str(cm.current.get("id", "")) == cid, 90.0)
			if not back:
				# No volvió sola en 90 s: se anota (y se ofrece a mano para poder seguir jugando la variante).
				m.fails.append("tras reconectar, el correo %s no volvió a entrar" % cid)
				return false
			return true
	return await m.step(st)  # los pasos de PC (Kardex, Correo, Portal, Identa): dev/manos_pc.gd


func _line(cid: String, kind: String, name: String, r: Dictionary) -> void:
	if OS.get_cmdline_user_args().has("--fbm-tabla"):
		print("[fbm] %s | %s | %s | %s | %s | %s | %s" % [cid, kind, name, str(r.get("outcome", "")) if str(r.get("outcome", "")) != "" else "(sin cerrar)", ",".join(PackedStringArray(r.get("qa", []))), ",".join(PackedStringArray(r.get("deaths", []))), " / ".join(PackedStringArray(r.get("fails", [])))])


func _mail(t: Node, cid: String) -> void:
	var c := case_by_id(cid)
	if not t.check(not c.is_empty() and str(c.get("canal", "")) == "correo", "existe el correo %s" % cid):
		return
	var vs := _variants(c)
	var only := ""
	var args := OS.get_cmdline_user_args()
	var oi := args.find("--fbm-solo")
	if oi >= 0 and oi + 1 < args.size():
		only = args[oi + 1]
	for v in vs[0]:
		if only != "" and not str(v["n"]).contains(only):
			continue
		var r: Dictionary = await _play(t, c, v["s"])
		_line(cid, "bien", str(v["n"]), r)
		t.check((r["fails"] as Array).is_empty(), "%s · %s: las manos pudieron hacer todos los pasos (%s)" % [cid, v["n"], str(r["fails"])])
		t.check(str(r["outcome"]) == "bo_ok" and ((r["deaths"] as Array).is_empty() or (v["s"] as Array).has("morir")), "%s · %s → bien resuelto (salió %s %s %s)" % [cid, v["n"], str(r["outcome"]), str(r["qa"]), str(r["deaths"])])
		if str(r["outcome"]) == "bo_ok":
			t.check(str(r["msg"]) == t.tr("KARDEX_RESOLVED"), "%s · %s: el aviso dice «%s» (dijo «%s»)" % [cid, v["n"], t.tr("KARDEX_RESOLVED"), str(r["msg"])])
	for v in vs[1]:
		if only != "" and not str(v["n"]).contains(only):
			continue
		var r: Dictionary = await _play(t, c, v["s"])
		_line(cid, "mal", str(v["n"]), r)
		t.check((r["fails"] as Array).is_empty(), "%s · MAL %s: las manos pudieron hacer todos los pasos (%s)" % [cid, v["n"], str(r["fails"])])
		t.check(str(r["outcome"]) == "bo_miss", "%s · MAL %s → mal resuelto (salió %s)" % [cid, v["n"], str(r["outcome"])])
		t.check((r["qa"] as Array).has(str(v["why"])), "%s · MAL %s: motivo %s (salió %s)" % [cid, v["n"], str(v["why"]), str(r["qa"])])
		t.check((r["qa"] as Array).size() == 1, "%s · MAL %s: un solo motivo, el que falló (salió %s)" % [cid, v["n"], str(r["qa"])])
		if str(r["outcome"]) == "bo_miss":
			t.check(str(r["msg"]) == t.tr("P4_CASE_MISS"), "%s · MAL %s: el aviso dice «%s»" % [cid, v["n"], t.tr("P4_CASE_MISS")])


func _kyc(t: Node) -> void:
	for c in all_cases():
		if str(c.get("canal", "")) != "kyc":
			continue
		var cid := str(c.get("id", ""))
		var good := str(c.get("correcto", ""))
		var plays := [
			{"n": "decisión correcta", "s": ["aceptar", "kyc:" + good], "ok": true},
			{"n": "con clics lentos y mirando otras apps antes", "s": ["lento", "aceptar_boton", "app:kardex", "app:campus", "kyc:" + good], "ok": true},
			{"n": "clic normal de ratón (0,12 s) en «Aceptar» de Fonex y en la decisión", "s": ["humano", "aceptar_boton", "kyc:" + good], "ok": true},
			{"n": "salir y volver antes de decidir", "s": ["aceptar", "pararse", "alejar", "kyc:" + good], "ok": true},
		]
		var wrong := "aprobar" if good != "aprobar" else "rechazar"
		plays.append({"n": "decisión equivocada (%s)" % wrong, "s": ["aceptar", "kyc:" + wrong], "ok": false, "why": "kyc_" + wrong})
		for v in plays:
			var r: Dictionary = await _play(t, c, v["s"])
			_line(cid, "bien" if bool(v["ok"]) else "mal", str(v["n"]), r)
			t.check((r["fails"] as Array).is_empty(), "%s · %s: las manos pudieron (%s)" % [cid, v["n"], str(r["fails"])])
			if bool(v["ok"]):
				t.check(str(r["outcome"]) == "bo_ok", "%s · %s → bien resuelto (salió %s %s)" % [cid, v["n"], str(r["outcome"]), str(r["qa"])])
			else:
				t.check(str(r["outcome"]) == "bo_miss" and (r["qa"] as Array) == [str(v["why"])], "%s · %s → mal resuelto con motivo %s (salió %s %s)" % [cid, v["n"], str(v["why"]), str(r["outcome"]), str(r["qa"])])


func _difficulties(t: Node) -> void:
	for cid in MAILS:
		var c := case_by_id(cid)
		var vs := _variants(c)
		var good: Array = vs[0][0]["s"]
		var bad: Dictionary = vs[1][0]
		for dif in [0, 1, 2]:
			var r: Dictionary = await _play(t, c, good, dif)
			_line(cid, "bien", "dificultad %d" % dif, r)
			t.check((r["fails"] as Array).is_empty() and str(r["outcome"]) == "bo_ok", "%s en dificultad %d (0 fácil, 1 normal, 2 difícil): camino correcto → bien resuelto (salió %s %s %s)" % [cid, dif, str(r["outcome"]), str(r["qa"]), str(r["fails"])])
			var rb: Dictionary = await _play(t, c, bad["s"], dif)
			_line(cid, "mal", "dificultad %d · %s" % [dif, bad["n"]], rb)
			t.check(str(rb["outcome"]) == "bo_miss" and (rb["qa"] as Array) == [str(bad["why"])], "%s en dificultad %d: «%s» → mal resuelto con el mismo motivo %s (salió %s %s)" % [cid, dif, bad["n"], bad["why"], str(rb["outcome"]), str(rb["qa"])])
		for ag in AGENTS:
			if ag == "Jiroshi":
				continue
			var r2: Dictionary = await _play(t, c, good, 1, ag)
			_line(cid, "bien", "agente " + ag, r2)
			t.check((r2["fails"] as Array).is_empty() and str(r2["outcome"]) == "bo_ok", "%s con %s: camino correcto → bien resuelto (salió %s %s %s)" % [cid, ag, str(r2["outcome"]), str(r2["qa"]), str(r2["fails"])])


func _trap(t: Node) -> void:
	for cid in ["vz_status", "vz_pod", "vz_reversal"]:
		var c := case_by_id(cid)
		var r: Dictionary = await _play(t, c, ["aceptar", "kardex", "dest:Vitzo", "tpl:" + ("POD request" if cid == "vz_pod" else "Status"), "copiar:id", "copiar:monto", "copiar:fecha", "enviar", "espera:6"])
		_line(cid, "trampa", "correo a Vitzo", r)
		t.check((r["fails"] as Array).is_empty(), "%s · correo a Vitzo: las manos pudieron (%s)" % [cid, str(r["fails"])])
		t.check((r["deaths"] as Array).has("correo_vitzo"), "%s · correo a Vitzo → muerte correo_vitzo, como siempre (%s)" % [cid, str(r["deaths"])])
		await t.wait_death_shown(30.0)
		await t.reconnect()


# --- punto 8: los pasos que se le muestran al jugador ---------------------------------------------------------------------

## Lo que cada correo debe mostrar en la barra una vez que Kardex dice quién es el partner.
const WANT_STEPS := {
	"t1_correo_pod": ["kardex", "destinatario", "plantilla", "campos", "enviar", "tipificar", "cerrar"],
	"t2_correo_reversal": ["kardex", "destinatario", "plantilla", "campos", "enviar", "tipificar", "cerrar"],
	"t3_correo_status": ["kardex", "destinatario", "plantilla", "campos", "enviar", "tipificar", "cerrar"],
	"vz_status": ["kardex", "portal", "destinatario", "plantilla", "campos", "enviar", "tipificar", "cerrar"],
	"vz_pod": ["kardex", "portal", "destinatario", "plantilla", "campos", "adjunto", "enviar", "tipificar", "cerrar"],
	"vz_reversal": ["kardex", "portal", "tipificar", "cerrar"],
}


func _bar_steps(correo: PcCorreo) -> Array:
	var out: Array = []
	for ch in correo.find_child("BarraPasos", true, false).get_children():
		out.append(str(ch.name).trim_prefix("Paso_"))
	return out


func _steps(t: Node) -> void:
	for lang in ["es", "en"]:
		Loc.set_language(lang)
		await t.frames(2)
		for cid in MAILS:
			var c := case_by_id(cid)
			var corr: Dictionary = c.get("correcto", {})
			await t.start_shift("Jiroshi", int(c.get("_turno", 1)))
			await t.login_at_seat()
			(SaveSlots.progress().get("tooltips_vistos", []) as Array).erase(PcCorreo.GUIDE_FLAG)  # la guía del primer correo
			var cm := _cm(t)
			var m = Manos.new()
			m.setup(t.main)
			(m.ws as Node).set("layout_area_override", Vector2(1280, 720))
			var correo: PcCorreo = m.desk.correo
			correo._guide_off = false
			correo._guide_case = ""
			cm.phase = ContactManager.Phase.IDLE
			cm._offer(c.duplicate(true))
			await t.frames(2)
			await m.accept()
			await m.app("correo")
			await t.frames(3)
			var tag := "%s [%s]" % [cid, lang]
			if OS.get_cmdline_user_args().has("--fbm-traza"):
				print("[fbm_pasos] %s · aceptado, fase %d, fallos %s" % [tag, cm.phase, str(m.fails)])
			var vitzo := str(c.get("vitzo", "")) != ""
			# Antes de Kardex: los siete pasos de siempre, sin «Adjunto» ni casilla de adjuntar.
			t.check(_bar_steps(correo) == CasoBO.STEPS_MAIL, "%s: antes de Kardex, los 7 pasos del correo normal (%s)" % [tag, str(_bar_steps(correo))])
			var att := correo.find_child("Adjunto", true, false) as CheckBox
			t.check(att == null or not att.visible, "%s: antes de Kardex no hay casilla de adjuntar" % tag)
			var guide := correo.find_child("GuiaCorreo", true, false) as Control
			t.check(guide != null and guide.visible, "%s: guía del primer correo a la vista" % tag)
			await m.kardex_lookup("enlace")
			await m.app("correo")
			await t.frames(3)
			# Después de Kardex: los pasos de ESTE caso.
			t.check(_bar_steps(correo) == WANT_STEPS[cid], "%s: pasos tras Kardex %s (salió %s)" % [tag, str(WANT_STEPS[cid]), str(_bar_steps(correo))])
			t.check(_bar_steps(correo).has("adjunto") == bool(corr.get("adjunto_pod", false)), "%s: «Adjunto» en la barra solo si el caso pide el POD" % tag)
			att = correo.find_child("Adjunto", true, false) as CheckBox
			t.check((att != null and att.visible) == vitzo, "%s: casilla de adjuntar %s" % [tag, "a la vista (caso de Vitzo)" if vitzo else "oculta (el partner no es Vitzo: no se adjunta nada)"])
			# Las etiquetas de la barra caben enteras (nada recortado con «…»).
			for ch in correo.find_child("BarraPasos", true, false).get_children():
				var lb := (ch as Node).find_children("*", "Label", true, false)[0] as Label
				var need: float = lb.get_theme_font("font").get_string_size(lb.text, HORIZONTAL_ALIGNMENT_LEFT, -1, lb.get_theme_font_size("font_size")).x
				t.check(need <= lb.size.x + 0.5, "%s: la etiqueta «%s» cabe en la barra (%.0f px de %.0f)" % [tag, lb.text, need, lb.size.x])
			# Recorrer el caso con las manos por el camino correcto, mirando qué paso marca la barra, qué dice la guía
			# y qué dice el panel «Siguiente paso» en cada momento.
			var good: Array = _variants(c)[0][0]["s"]
			var guide_lbl: Label = correo._guide_lbl
			var seen_guides: Array = []
			var tip_early := false
			for st in good.slice(2):  # aceptar y kardex ya están
				var cur := correo.current_step()
				var gk := correo.guide_key(cur)
				correo.refresh(0.0)
				if guide.visible and not seen_guides.has(gk):
					seen_guides.append(gk)
					t.check(guide_lbl.text.contains(t.tr(gk)) and t.tr(gk) != gk, "%s: en el paso «%s» la guía dice «%s»" % [tag, cur, t.tr(gk)])
					var n := (WANT_STEPS[cid] as Array).find(cur) + 1
					t.check(guide_lbl.text.contains(Loc.fmt(t.tr("Q4_GUIDE_HEAD"), {"n": n, "total": (WANT_STEPS[cid] as Array).size()})), "%s: la guía numera «paso %d de %d» (dice «%s»)" % [tag, n, (WANT_STEPS[cid] as Array).size(), guide_lbl.text.left(60)])
				# El panel «Siguiente paso» nunca manda a tipificar con trabajo del partner pendiente.
				if cur in ["portal", "destinatario", "plantilla", "campos", "adjunto", "enviar"] and cm.case.next_step_key() != "P4_STEP_PARTNER":
					tip_early = true
				if OS.get_cmdline_user_args().has("--fbm-traza"):
					print("[fbm_pasos] %s · %s (paso de la barra: %s)" % [tag, str(st), cur])
				var okk: bool = await _step(t, m, cm, c, str(st))
				if not okk:
					break
				await t.frames(2)
			t.check(m.fails.is_empty(), "%s: las manos hicieron el camino (%s)" % [tag, str(m.fails)])
			t.check(not tip_early, "%s: «Siguiente paso» no dice «Tipifica» mientras falte el portal o el correo" % tag)
			if not vitzo:
				t.check(not seen_guides.has("Q4_GUIDE_ADJUNTO"), "%s: la guía nunca pide adjuntar (guías vistas: %s)" % [tag, str(seen_guides)])
			if cid == "vz_pod":
				t.check(seen_guides.has("Q4_GUIDE_ADJUNTO") and seen_guides.has("Q4_GUIDE_PORTAL_POD") and seen_guides.has("Q4_GUIDE_DESTINATARIO_VZ"), "%s: la guía pide Portal → descargar POD → adjuntar → responder a quien lo pidió (%s)" % [tag, str(seen_guides)])
			(m.ws as Node).set("layout_area_override", Vector2.ZERO)
	Loc.set_language("es")
	# `sin_pod` solo puede salir en un caso que pedía el POD: cada correo, bien y mal hecho, SIN adjuntar nada.
	for cid in MAILS:
		var c := case_by_id(cid)
		var needs := bool((c.get("correcto", {}) as Dictionary).get("adjunto_pod", false))
		for v in _variants(c)[0].slice(0, 1) + _variants(c)[1]:
			var had_attach := (v["s"] as Array).has("pod_adjuntar") or (v["s"] as Array).has("adjuntar")
			var r: Dictionary = await _play(t, c, (v["s"] as Array).filter(func(x: Variant) -> bool: return not str(x) in ["pod_adjuntar", "adjuntar"]))
			if not needs:
				t.check(not (r["qa"] as Array).has("sin_pod"), "%s · %s: nunca «sin_pod» en un caso que no pedía POD (%s)" % [cid, v["n"], str(r["qa"])])
			elif (v["s"] as Array).has("enviar"):
				t.check(str(r["outcome"]) == "bo_miss" and (r["qa"] as Array).has("sin_pod"), "%s · %s%s: el correo sale sin el POD que pedían → «sin_pod» (%s %s)" % [cid, v["n"], " (sin adjuntar)" if had_attach else "", str(r["outcome"]), str(r["qa"])])


## Los textos que explican la regla dicen lo mismo que la nota (ES y EN).
func _texts(t: Node) -> void:
	var manual := JSON.stringify(DataLoader.dict("manual_agente"))
	t.check(manual.contains("no se adjunta nada") and manual.contains("nothing to attach"), "manual · POD: a un partner normal se le pide, no se adjunta nada (ES y EN)")
	t.check(manual.contains("se adjunta en la respuesta a quien lo pidió") and manual.contains("attach it to your reply to whoever asked"), "manual · Vitzo: el POD se descarga del Portal y se adjunta en la respuesta (ES y EN)")
	t.check(manual.contains("«POD» o «POD request»") and manual.contains("«POD» or «POD request»"), "manual · casos: plantilla «POD» o «POD request» para pedirlo (ES y EN)")
	for lang in ["es", "en"]:
		Loc.set_language(lang)
		await t.frames(1)
		# La guía del adjunto habla del Portal Vitzo; la del destinatario normal, del partner de Kardex.
		t.check(t.tr("Q4_GUIDE_ADJUNTO").contains("Vitzo"), "[%s] guía «Adjunto»: solo el POD del Portal Vitzo" % lang)
		t.check(not t.tr("Q4_GUIDE_ADJUNTO").to_lower().contains("si el caso") and not t.tr("Q4_GUIDE_ADJUNTO").to_lower().contains("if the case"), "[%s] guía «Adjunto»: ya no dice «si el caso pide…»" % lang)
		for k in ["Q4_STEP_PORTAL", "Q4_GUIDE_PORTAL_BUSCAR", "Q4_GUIDE_PORTAL_POD", "Q4_GUIDE_PORTAL_REVERSAL", "Q4_GUIDE_PORTAL_CONTACTO", "Q4_GUIDE_DESTINATARIO_VZ", "HINT_VITZO_POD", "HINT_VITZO_REVERSAL"]:
			t.check(t.tr(k) != k and t.tr(k) != "", "[%s] existe el texto %s" % [lang, k])
	Loc.set_language("es")
	# Pista de Fácil por tipo de caso de Vitzo.
	for cid in ["vz_status", "vz_pod", "vz_reversal"]:
		var k := CasoBO.new(case_by_id(cid))
		var want: String = {"vz_status": "HINT_PARTNER_VITZO", "vz_pod": "HINT_VITZO_POD", "vz_reversal": "HINT_VITZO_REVERSAL"}[cid]
		t.check(AgentTips._vitzo_hint(k) == want, "%s: pista de Fácil %s" % [cid, want])
	# Plantillas: pedir un POD a un partner normal vale con «POD» y con «POD request»; mandar el POD de Vitzo, solo «POD».
	t.check(CasoBO.new(case_by_id("t1_correo_pod")).valid_templates() == ["POD", "POD request"], "pedir POD al partner: plantilla «POD» o «POD request»")
	t.check(CasoBO.new(case_by_id("vz_pod")).valid_templates() == ["POD"], "enviar el POD de Vitzo al banco: solo «POD»")
	t.check(CasoBO.new(case_by_id("t2_correo_reversal")).valid_templates() == ["Reversal"] and CasoBO.new(case_by_id("vz_status")).valid_templates() == ["Status"], "las demás plantillas, una sola")
	# Haime tiene línea para cada motivo que la nota puede dar en un correo.
	var hg: Dictionary = DataLoader.dict("haime_guiones")
	var txt := JSON.stringify(hg)
	for mark in ["sin_enviar", "destinatario_equivocado", "correo_plantilla", "correo_campo_id", "correo_campo_monto", "correo_campo_fecha", "sin_pod", "tipificacion", "correo_innecesario", "falta_portal"]:
		t.check(txt.contains("q4_bo_%s_1" % mark), "Haime tiene línea para «%s»" % mark)
	# El minitraining del Mentor sobre Vitzo dice la misma regla (Portal → Descargar POD → adjuntar y responder al banco).
	var mentor := JSON.stringify(DataLoader.dict("lineas_mentor"))
	t.check(mentor.contains("Portal Vitzo → Descargar POD → adjuntar y responder al banco"), "Mentor · «Vitzo: solo portal»: la respuesta correcta es descargar del Portal, adjuntar y responder al banco")
