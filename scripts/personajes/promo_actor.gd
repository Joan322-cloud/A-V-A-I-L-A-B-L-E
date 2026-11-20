class_name PromoActor
extends TrainingActor
## v0.3.2 · Un compañero de tu promoción en el Training (el recuerdo): Nayra, Yimi, Zuly o Kenyi. Recién contratado,
## contento y nervioso. No es ninguno de los otros agentes ni un personaje de hoy: usa un modelo base del juego con
## su propia textura de civil (assets/textures/promo_<nombre>.jpg, hecha por tools/v032_promo_texturas.py) y el pelo
## oscuro; si la textura falta, la ropa se tiñe. Se sienta en su puesto de la herradura; TrainingStage lo hace reír,
## aplaudir, levantar la mano, ir por café y posar para la foto.

const TEX_DIR := "res://assets/textures/"
const HAIR := {"Llauri": Color(0.13, 0.09, 0.07), "Marko": Color(0.16, 0.2, 0.34), "Ttoom": Color(0.14, 0.11, 0.09), "Juan": Color(0.1, 0.09, 0.09)}
const HEIGHTS := {"Llauri": 1.62, "Marko": 1.74, "Ttoom": 1.68, "Juan": 1.72}

var who: String = ""
var index: int = 0
var tint: Color = Color(1, 1, 1)
var seat_pos: Vector3 = Vector3.ZERO
var seat_face: Vector3 = Vector3(0, 0, -1)


func _ready() -> void:
	add_to_group("promocion")
	speed = 1.25 + 0.06 * index
	if not build(model, float(HEIGHTS.get(who, 1.66)), ""):
		Greybox.box(self, "Cuerpo", Vector3(0, 0.85, 0), Vector3(0.38, 0.8, 0.26), tint, false)
		return
	_civil()
	look_at_player(false)  # atiende a la clase; te mira cuando te habla (TrainingStage)
	place_seated(seat_pos, seat_face, "type" if index % 2 == 1 else "sit")


## Vuelve a su silla (caminando desde donde esté).
func go_seat(via: Array = []) -> void:
	walk_and_sit(via, seat_pos, seat_face, "sit")


## Ropa de civil: su textura propia si existe; si no, el tinte. El gorro del modelo pasa a ser pelo (o gorra) oscuro.
func _civil() -> void:
	if rig != null and rig.is_v2 and model.begins_with("agente_"):
		return
	var path := TEX_DIR + "promo_" + who.to_lower() + ".jpg"
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i) as BaseMaterial3D
			if src == null:
				continue
			var nm := String(src.resource_name).to_lower()
			if nm.ends_with("_pelo"):
				var mat := src.duplicate() as BaseMaterial3D
				mat.albedo_color = HAIR.get(who, Color(0.16, 0.11, 0.08))
				m.set_surface_override_material(i, mat)
			elif nm.ends_with("_cuerpo") or nm.ends_with("_cara"):
				var mat2 := src.duplicate() as BaseMaterial3D
				if tex != null and nm.ends_with("_cuerpo"):
					mat2.albedo_texture = tex
				elif tex == null and nm.ends_with("_cuerpo"):
					mat2.albedo_color = Color(1, 1, 1).lerp(tint, 0.35)
				m.set_surface_override_material(i, mat2)
