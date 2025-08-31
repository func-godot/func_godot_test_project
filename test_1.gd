@tool
extends Node

@export_tool_button("Show Face Data") var show_face_data : Callable = _show_face_data

func _show_face_data() -> void:
	var fgm := $FuncGodotMap
	var scene_root = fgm.owner
	
	for c in fgm.get_children():
		if c.has_meta("func_godot_mesh_data"):
			var mdata: Dictionary = c.get_meta("func_godot_mesh_data", Dictionary())
			var t: PackedInt32Array = mdata["textures"]
			var tn: Array = mdata["texture_names"]
			var v: PackedVector3Array = mdata["vertices"]
			var n: PackedVector3Array = mdata["normals"]
			var p: PackedVector3Array = mdata["positions"]
			
			for i in t.size():
				var label := Label3D.new()
				label.text = tn[t[i]]
				label.font_size = 16
				label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				c.add_child(label)
				label.owner = scene_root
				label.position = p[i] + n[i] * 0.3
