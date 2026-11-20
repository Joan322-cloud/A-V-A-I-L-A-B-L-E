## Sin class_name: fixture del escenario p2 "comportamientos" (FloorBase._attach_behaviours).
extends Node

var marker_name: String = ""
var floor_number: int = 0


func setup_behaviour(fl: Node, marker: Node, _entry: Dictionary) -> void:
	floor_number = int(fl.get("floor_number"))
	marker_name = str(marker.name) if marker != null else ""
