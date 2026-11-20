class_name CasoBO
extends RefCounted
## Estado de un caso de BO abierto (PLAN §6.1-6.3): correo con trabajo real (Kardex → destinatario →
## plantilla → 3 campos → enviar → tipificar → cerrar), caso de correo de Vitzo (Portal Vitzo) o KYC (Identa).
## Lógica pura: las apps de la PC lo modifican y ContactManager lo cierra y lo evalúa. Todo se puede cambiar
## antes de enviar (deshacer = volver a elegir); enviar es definitivo, como en la vida real.
##
## v0.3.2 (Joan: «¿por qué los pasos me piden adjuntar si el caso no es de Vitzo?» y «los correos de Vitzo y otros que
## hago bien salen como mal resueltos»). Las reglas, en un solo sitio (la barra de pasos del Correo, el panel
## «Siguiente paso», la guía del primer correo, la nota al cerrar y lo que Haime te dice salen todas de aquí):
##   · Partner que NO es Vitzo: Kardex → destinatario (el partner) → plantilla → 3 campos → enviar → tipificar →
##     cerrar. No se adjunta nada: si el caso pide un POD todavía no lo tienes, se lo pides al partner (plantilla
##     «POD», la que enseña el Training, o «POD request»: piden lo mismo) y tipificas «POD solicitado al partner».
##   · Partner Vitzo: Kardex → Portal Vitzo (buscar; descargar el POD o registrar el reversal si el caso lo pide) →
##     si hay que responder a alguien (al banco o al cliente, NUNCA a Vitzo): destinatario → plantilla → campos →
##     adjunto (solo si pidieron un POD) → enviar → tipificar → cerrar.
##   · Lo que no estorba no resta: un correo de cortesía al cliente («Al cliente sí se le responde por correo»),
##     adjuntar un POD que nadie pidió, pulsar «Contacto partner», buscar dos veces.

const FIELDS: Array[String] = ["id", "monto", "fecha"]

var data: Dictionary = {}
var kardex_done: bool = false
var portal_done: Array[String] = []  # buscar · pod (descargado) · reversal · contacto
var recipient: String = ""
var template: String = ""
var fields: Dictionary = {"id": "", "monto": "", "fecha": ""}
var attach_pod: bool = false
var sent: Array = []  # [{to, tpl, fields, pod}]
var typification: String = ""
var kyc_action: String = ""
var notes: Array[String] = []  # registro de pasos (para QA y el resumen)


func _init(d: Dictionary = {}) -> void:
	data = d


func kind() -> String:
	return str(data.get("canal", "correo"))


func is_kyc() -> bool:
	return kind() == "kyc"


func tx() -> String:
	return str(data.get("tx", ""))


func vitzo_kind() -> String:
	return str(data.get("vitzo", ""))


func correct() -> Dictionary:
	return data.get("correcto", {})


## Datos de Kardex de la transacción del caso (casos_bo.json/transacciones).
func tx_info() -> Dictionary:
	return (DataLoader.dict("casos_bo").get("transacciones", {}) as Dictionary).get(tx(), {})


func partner() -> String:
	return str(tx_info().get("partner", ""))


func lookup_kardex(id: String) -> bool:
	if id.strip_edges().to_upper() != tx():
		return false
	if not kardex_done:
		kardex_done = true
		notes.append("kardex")
	return true


func portal_mark(action: String) -> void:
	if not portal_done.has(action):
		portal_done.append(action)
		notes.append("portal_" + action)


func set_field(key: String, value: String) -> void:
	fields[key] = value


func fields_complete() -> bool:
	for k in FIELDS:
		if str(fields.get(k, "")) == "":
			return false
	return true


func can_send() -> bool:
	return recipient != "" and template != "" and fields_complete()


## Envía el borrador actual. Devuelve el correo enviado ({to, tpl, fields, pod}).
func send() -> Dictionary:
	var m := {"to": recipient, "tpl": template, "fields": fields.duplicate(), "pod": attach_pod}
	sent.append(m)
	notes.append("enviado:" + recipient)
	return m


func sent_to_vitzo() -> bool:
	for m in sent:
		if str(m.get("to", "")) == "Vitzo":
			return true
	return false


## ¿Qué falta? Lista de claves de paso pendientes (vacía = todo hecho), en orden.
func pending_steps() -> Array[String]:
	var out: Array[String] = []
	if is_kyc():
		if kyc_action == "":
			out.append("kyc_decidir")
		return out
	if not kardex_done:
		out.append("kardex")
	var c := correct()
	for p in c.get("portal", []):
		if not portal_done.has(str(p)):
			out.append("portal_" + str(p))
	if str(c.get("destinatario", "")) != "" and not _has_correct_mail():
		out.append("enviar")
	if typification == "":
		out.append("tipificar")
	return out


## Siguiente paso visible para el jugador (no revela la trampa: solo dice "según el partner pagador").
func next_step_key() -> String:
	if is_kyc():
		return "P4_STEP_KYC"
	if not kardex_done:
		return "P4_STEP_KARDEX"
	# v0.3.2: mientras falte lo del partner (su portal o el correo) el panel no manda a tipificar. Antes bastaba con
	# buscar en el Portal Vitzo para que dijera «Tipifica el caso»: quien le hacía caso cerraba sin responder.
	var st := current_step()
	if st in ["portal", "destinatario", "plantilla", "campos", "adjunto", "enviar"]:
		return "P4_STEP_PARTNER"
	if typification == "":
		return "P4_STEP_TIPIFICAR"
	return "P4_STEP_CERRAR"


## Plantillas que valen para el correo del caso. Un «POD» sin adjunto es PEDIR el POD al partner: vale la plantilla
## «POD» (la que enseña el Training) y también «POD request» (dicen lo mismo). Con adjunto (le mandas el POD a quien
## lo pidió) solo «POD». `correcto.plantillas` (lista) manda si el caso la trae.
func valid_templates() -> Array:
	var c := correct()
	if c.has("plantillas"):
		return (c.get("plantillas", []) as Array).duplicate()
	var tpl := str(c.get("plantilla", ""))
	if tpl == "POD" and not bool(c.get("adjunto_pod", false)):
		return ["POD", "POD request"]
	return [tpl]


## ¿El caso pide adjuntar el POD? (solo los de Vitzo en los que alguien pidió el comprobante)
func needs_pod() -> bool:
	return bool(correct().get("adjunto_pod", false))


## ¿El caso pide enviar un correo? (a quién: correct().destinatario)
func needs_mail() -> bool:
	return str(correct().get("destinatario", "")) != ""


func _has_correct_mail() -> bool:
	var c := correct()
	var tpls := valid_templates()
	for m in sent:
		if str(m.get("to", "")) != str(c.get("destinatario", "")):
			continue
		if not tpls.has(str(m.get("tpl", ""))):
			continue
		if bool(c.get("adjunto_pod", false)) and not bool(m.get("pod", false)):
			continue
		var ok := true
		var want: Dictionary = c.get("campos", {})
		for k in want.keys():
			if str((m.get("fields", {}) as Dictionary).get(k, "")) != str(want[k]):
				ok = false
		if ok:
			return true
	return false


## Evaluación al cerrar: {ok, motivos[]} (motivos = claves de QA).
## v0.3.2: `sin_pod` solo sale si el caso pedía el POD y ningún correo al destinatario correcto lo llevó; un correo
## de más al cliente no es ni «innecesario» ni «destinatario equivocado» (a un banco o a otro partner, sí).
func evaluate() -> Dictionary:
	var reasons: Array[String] = []
	if is_kyc():
		if kyc_action != str(data.get("correcto", "")):
			reasons.append("kyc_" + (kyc_action if kyc_action != "" else "sin_decision"))
		return {"ok": reasons.is_empty(), "motivos": reasons}
	var c := correct()
	for p in c.get("portal", []):
		if not portal_done.has(str(p)):
			reasons.append("falta_portal_" + str(p))
	var dest := str(c.get("destinatario", ""))
	if dest != "":
		if not _has_correct_mail():
			if _work_mails().is_empty():
				reasons.append("sin_enviar")  # una sola causa: no salió el correo (el POD no llegó porque no hubo correo)
			else:
				reasons.append("correo_incorrecto")
				if needs_pod() and not _pod_reached(dest):
					reasons.append("sin_pod")
	else:
		for m in _work_mails():
			reasons.append("correo_innecesario")
			break
	for m in _work_mails():
		if str(m.get("to", "")) != dest and dest != "":
			reasons.append("destinatario_equivocado")
			break
	if typification != str(c.get("tipificacion", "")):
		reasons.append("tipificacion")
	return {"ok": reasons.is_empty(), "motivos": reasons}


## Correos enviados que cuentan para la nota: ni los de Vitzo (eso es otra cosa: mata) ni los de cortesía al
## cliente cuando el caso no era responderle a él.
func _work_mails() -> Array:
	var dest := str(correct().get("destinatario", ""))
	var out: Array = []
	for m in sent:
		var to := str(m.get("to", ""))
		if to == "Vitzo" or (to == "Cliente" and dest != "Cliente"):
			continue
		out.append(m)
	return out


## El correo que se compara con el correcto para decir QUÉ falló: el último enviado a quien había que escribirle; si
## no hubo ninguno, el último que cuenta para la nota.
func reference_mail() -> Dictionary:
	var dest := str(correct().get("destinatario", ""))
	var last: Dictionary = {}
	var to_dest: Dictionary = {}
	for m in _work_mails():
		last = m
		if str((m as Dictionary).get("to", "")) == dest:
			to_dest = m
	return to_dest if not to_dest.is_empty() else last


func _pod_reached(dest: String) -> bool:
	for m in sent:
		if str(m.get("to", "")) == dest and bool(m.get("pod", false)):
			return true
	return false


# --- pasos del caso (barra del Correo, «Siguiente paso», guía) -----------------------------------------------------

const STEPS_MAIL: Array[String] = ["kardex", "destinatario", "plantilla", "campos", "enviar", "tipificar", "cerrar"]


## Los pasos de ESTE caso, en orden. Hasta buscar la operación en Kardex no se sabe quién es el partner pagador: salen
## los siete del correo normal (los del Training). Después, si el partner es Vitzo, entra el Portal y el resto depende
## de lo que el caso pide (responder o no, con POD o sin él).
func steps() -> Array[String]:
	if is_kyc():
		return ["kyc"]
	if not kardex_done or partner() != "Vitzo":
		return STEPS_MAIL.duplicate()
	var out: Array[String] = ["kardex", "portal"]
	if needs_mail():
		out.append_array(["destinatario", "plantilla", "campos"])
		if needs_pod():
			out.append("adjunto")
		out.append("enviar")
	out.append_array(["tipificar", "cerrar"])
	return out


func step_done(step: String) -> bool:
	match step:
		"kardex": return kardex_done
		"portal":
			var need: Array = correct().get("portal", [])
			if need.is_empty():
				return portal_done.has("buscar")
			for p in need:
				if not portal_done.has(str(p)):
					return false
			return true
		"destinatario": return recipient != ""
		"plantilla": return template != ""
		"campos": return fields_complete()
		"adjunto": return attach_pod or (not sent.is_empty() and bool((sent[-1] as Dictionary).get("pod", false)))
		"enviar": return not _work_mails().is_empty() if needs_mail() else not sent.is_empty()
		"tipificar": return typification != ""
	return false


## El paso que toca: el primero sin hacer (se puede ir en otro orden: lo ya hecho queda hecho).
func current_step() -> String:
	for st in steps():
		if st != "cerrar" and not step_done(st):
			return st
	return "cerrar"


## Qué acción del Portal falta ("buscar" | "pod" | "reversal" | "contacto" | "").
func portal_pending() -> String:
	if not portal_done.has("buscar"):
		return "buscar"
	for p in correct().get("portal", []):
		if not portal_done.has(str(p)):
			return str(p)
	return ""
