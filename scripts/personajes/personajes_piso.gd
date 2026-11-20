extends Node
## Ancla de P5 en los pisos sin otro comportamiento de P5 (azotea): crea PersonajesP5 si todavía no existe
## (p. ej. al continuar una partida cuyo checkpoint quedó en el piso 9). data/comportamientos.json.


func setup_behaviour(_fl: Node, _marker: Node, _entry: Dictionary) -> void:
	PersonajesP5.ensure(get_tree())
