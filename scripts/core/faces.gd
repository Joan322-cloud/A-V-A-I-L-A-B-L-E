class_name Faces
extends RefCounted
## Caras y avatares (GDD 8.4): carga res://assets/faces/<slug>.png si existe (importado o no),
## si no devuelve una silueta generada. También fabrica la textura del "reflejo en el monitor apagado".

const FACES_DIR := "res://assets/faces/"

static var _cache: Dictionary = {}


static func has_face(slug: String) -> bool:
	var path := FACES_DIR + slug + ".png"
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


## Textura de la cara (512 px) o silueta placeholder.
static func texture(slug: String) -> Texture2D:
	var key := "face_" + slug
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	var path := FACES_DIR + slug + ".png"
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null:
			tex = ImageTexture.create_from_image(img)
	if tex == null:
		tex = ImageTexture.create_from_image(silhouette(128, Color(0.12, 0.13, 0.15), Color(0.03, 0.03, 0.04)))
	_cache[key] = tex
	return tex


## Textura cualquiera (ui/…): importada o cargada del archivo. null si no existe.
static func texture_at(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null:
			tex = ImageTexture.create_from_image(img)
	if tex != null:
		_cache[path] = tex
	return tex


## Cara/avatar según el estado (v0.3 P6): Shero enojado (desde el WW, en la persecución, en sus screamers) es
## "shero_calvo". Pregunta a Discipline.shero_bald() (P3) si existe; si no, al nodo de Shero (bald / look).
static func mood_slug(slug: String) -> String:
	if slug == "shero" and shero_is_bald():
		return "shero_calvo"
	return slug


static func shero_is_bald() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var disc := tree.root.get_node_or_null("Discipline")
	if disc != null and disc.has_method("shero_bald"):
		return bool(disc.call("shero_bald"))
	for n in tree.get_nodes_in_group("shero"):
		if "bald" in n and bool(n.get("bald")):
			return true
		if "look" in n and str(n.get("look")) == "calvo":
			return true
	return false


## Avatar (128 px, assets/ui/ezlak/<slug>.png) de quien te mató, para la pantalla "Usuario desconectado".
## Shero sale calvo (siempre lo está cuando mata); colapso = tu propia cara (nadie te mató).
static func killer_avatar_slug(killer: String) -> String:
	match killer:
		"shero", "cliente":
			return "shero_calvo"
		"rta":
			return "perrito_rta_enojado"
		"trainer":
			return "trainer_grito"
		"guardia":
			return "guardia_fermin"
		"", "fatiga":
			return agent_slug(GameState.agent)
		_:
			return killer


## Slug de cara de un agente jugable (v0.3 P6: Juan ya tiene cara en ref_caras_v2; la silueta queda de respaldo).
static func agent_slug(agent: String) -> String:
	var s := agent.to_lower()
	return s if has_face(s) else ("juan_silueta" if s == "juan" else s)


## Silueta cabeza + hombros sobre fondo.
static func silhouette(size: int, fg: Color, bg: Color) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	var cx := size * 0.5
	var head_r := size * 0.22
	var head_cy := size * 0.38
	for y in size:
		for x in size:
			var dx := x - cx
			var dy := y - head_cy
			var in_head := dx * dx + dy * dy <= head_r * head_r
			var sh_y := size * 0.72
			var in_shoulders := y >= sh_y and absf(dx) <= size * 0.42 * minf(1.0, (y - sh_y) / (size * 0.12) + 0.4)
			if in_head or in_shoulders:
				img.set_pixel(x, y, fg)
	return img


## Reflejo para la pantalla apagada: silueta oscura y, si hay cara, la cara muy atenuada dentro de la cabeza.
static func reflection_texture(slug: String) -> Texture2D:
	var key := "reflection_" + slug
	if _cache.has(key):
		return _cache[key]
	var w := 320
	var h := 200
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0))
	var sil := silhouette(h, Color(0.11, 0.115, 0.13), Color(0, 0, 0, 0))
	var face: Image = null
	var path := FACES_DIR + slug + ".png"
	# P7: en el export solo queda la textura importada (el .png original no va en el .pck): se lee su imagen.
	if ResourceLoader.exists(path):
		var t := load(path) as Texture2D
		face = t.get_image() if t != null else null
		if face != null and face.is_compressed():
			face.decompress()
	elif FileAccess.file_exists(path):
		face = Image.load_from_file(path)
	if face != null:
		face = face.duplicate() as Image
		if face != null:
			face.convert(Image.FORMAT_RGBA8)
			face.resize(int(h * 0.44), int(h * 0.44), Image.INTERPOLATE_BILINEAR)
	var ox := int((w - h) * 0.5)
	for y in h:
		for x in h:
			var c := sil.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			img.set_pixel(x + ox, y, c)
	if face != null:
		var fx := int(w * 0.5 - face.get_width() * 0.5)
		var fy := int(h * 0.38 - face.get_height() * 0.5)
		var r := face.get_width() * 0.5
		for y in face.get_height():
			for x in face.get_width():
				var dx := x - r
				var dy := y - r
				if dx * dx + dy * dy > r * r:
					continue
				var fc := face.get_pixel(x, y)
				var lum := fc.get_luminance() * 0.28
				img.set_pixel(fx + x, fy + y, Color(lum, lum * 1.05, lum * 1.15))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
