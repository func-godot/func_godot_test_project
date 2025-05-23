class_name FuncGodotMapData2 extends RefCounted

class FuncGodotBrushData extends RefCounted:
	var planes: Array[Plane]
	var textures: PackedStringArray
	var uvs: Array[Transform2D]
	var uv_axes: PackedVector3Array
	#var vertices: PackedVector3Array

class FuncGodotPatchData extends RefCounted:
	var texture: String
	var size: PackedInt32Array
	var points: PackedVector3Array
	var uvs: PackedVector2Array

class FuncGodotEntityData extends RefCounted:
	var properties: Dictionary = {}
	var brushes: Array[FuncGodotBrushData] = []
	var patches: Array[FuncGodotPatchData] = []

func parse_map_data(map_file: String) -> Array[FuncGodotEntityData]:
	var map_data: PackedStringArray = []
	# Retrieve real path if needed
	if map_file.begins_with("uid://"):
		var uid := ResourceUID.text_to_id(map_file);
		if !ResourceUID.has_id(uid):
			printerr("Error: failed to retrieve path for UID (%s)" % map_file)
			return []
		map_file = ResourceUID.get_id_path(uid);
	
	# Open the map file
	var file: FileAccess = FileAccess.open(map_file, FileAccess.READ)
	if not file:
		printerr("Error: Failed to open map file (" + map_file + ")")
		return []
	
	# Packed map file resources need to be accessed differently in exported projects.
	if map_file.ends_with(".import"):
		while not file.eof_reached():
			var line: String = file.get_line()
			if line.begins_with("path"):
				file.close()
				line = line.replace("path=", "");
				line = line.replace('"', '')
				var data: String = (load(line) as QuakeMapFile).map_data
				if data.is_empty():
					printerr("Error: Failed to open map file (" + line + ")")
					return []
				map_data = data.split("\n")
				break
	else:
		while not file.eof_reached():
			map_data.append(file.get_line())
	
	if map_file.contains(".map"):
		return _parse_qmap(map_data)
	elif map_file.contains(".vmf"):
		return _parse_vmf(map_data)
	return []

func _parse_qmap(map_data: PackedStringArray) -> Array[FuncGodotEntityData]:
	var entities_data: Array[FuncGodotEntityData] = []
	var ent: FuncGodotEntityData = null
	var brush: FuncGodotBrushData = null
	var patch: FuncGodotPatchData = null
	var scope: int = 0 # Scope level, to keep track of where we are in PatchDef parsing
	
	for line in map_data:
		#region START DATA
		# Start entity, brush, or patchdef
		if line.begins_with("{"):
			if not ent:
				ent = FuncGodotEntityData.new()
			else:
				if not patch:
					brush = FuncGodotBrushData.new()
				else:
					scope += 1
			continue
		#endregion
		
		#region COMMIT DATA
		# Commit entity or brush
		if line.begins_with("}"):
			if brush:
				ent.brushes.append(brush)
				brush = null
			elif patch:
				if scope:
					scope -= 1
				else:
					ent.patches.append(patch)
					patch = null
			else:
				entities_data.append(ent)
				ent = null
			continue
		#endregion
		
		#region PROPERTY DATA
		# Retrieve key value pairs
		if line.begins_with("\""):
			var tokens: PackedStringArray = line.split("\" \"")
			var key: String = tokens[0].trim_prefix("\"")
			var value: String = tokens[1].trim_suffix("\"")
			ent.properties[key] = value
		#endregion
		
		#region BRUSH DATA
		if brush and line.begins_with("("):
			line = line.replace("(","")
			var tokens: PackedStringArray = line.split(" ) ")
			
			# Retrieve plane data
			var points: PackedVector3Array
			points.resize(3) 
			for i in 3:
				tokens[i] = tokens[i].trim_prefix("(")
				var pts: PackedFloat64Array = tokens[i].split_floats(" ", false)
				var point: Vector3 = Vector3(pts[0], pts[1], pts[2])
				points[i] = point
			brush.planes.append(Plane(points[0], points[1], points[2]))
			
			# Retrieve texture data
			var tex: String = String()
			if tokens[3].begins_with("\""): # textures with spaces get surrounded by double quotes
				tex = tokens[3].split("\"")[0]
			else:
				tex = tokens[3].split(" ")[0]
			brush.textures.append(tex)
			
			# Retrieve UV data
			var uv: Transform2D = Transform2D.IDENTITY
			tokens = tokens[3].lstrip(tex + " ").split(" ] ")
			# Valve 220
			if tokens.size() > 1:
				var coords: PackedFloat64Array
				for i in 2: # Save Axis Vectors separately
					coords = tokens[i].trim_prefix("[ ").split_floats(" ", false)
					brush.uv_axes.append(Vector3(coords[0], coords[1], coords[2]))
					uv.origin[i] = coords[3]
				coords = tokens[2].split_floats(" ", false)
				var r: float = deg_to_rad(coords[0])
				uv.x = Vector2(cos(r), -sin(r)) * coords[1]
				uv.y = Vector2(sin(r), cos(r)) * coords[2]
			# Quake Standard
			else:
				var coords: PackedFloat64Array = tokens[0].split_floats(" ", false)
				uv.origin = Vector2(coords[0], coords[1])
				var r: float = deg_to_rad(coords[2])
				uv.x = Vector2(cos(r), -sin(r)) * coords[3]
				uv.y = Vector2(sin(r), cos(r)) * coords[4]
			brush.uvs.append(uv)
			continue
		#endregion
	
		#region PATCH DATA
		if patch:
			if line.begins_with("("):
				line = line.replace("( ","")
				# Retrieve patch control points
				if patch.size:
					var tokens: PackedStringArray = line.replace("(", "").split(" )", false)
					for i in tokens.size():
						var subtokens: PackedFloat64Array = tokens[i].split_floats(" ", false)
						patch.points.append(Vector3(subtokens[0], subtokens[1], subtokens[2]))
						patch.uvs.append(Vector2(subtokens[3], subtokens[4]))
				# Retrieve patch size
				else:
					var tokens: PackedStringArray = line.replace(")","").split(" ", false)
					patch.size.resize(tokens.size())
					for i in tokens.size():
						patch.size[i] = tokens[i].to_int()
			# Retrieve patch texture
			elif not line.begins_with(")"):
				patch.texture = line.replace("\"","")
		
		if line.begins_with("patchDef"):
			brush = null
			patch = FuncGodotPatchData.new()
			continue
		#endregion
	
	return entities_data

func _parse_vmf(map_data: PackedStringArray) -> Array[FuncGodotEntityData]:
	var entities_data: Array[FuncGodotEntityData] = []
	var ent: FuncGodotEntityData = null
	var brush: FuncGodotBrushData = null
	var scope: int = 0
	
	for line in map_data:
		#region START DATA
		if line.begins_with("entity") or line.begins_with("world"):
			ent = FuncGodotEntityData.new()
			continue
		if line.begins_with("solid"):
			brush = FuncGodotBrushData.new()
			continue
		if brush and line.begins_with("{"):
			scope += 1
			continue
		#endregion
		
		#region COMMIT DATA
		if line.begins_with("}"):
			if scope > 0:
				scope -= 1
			if not scope:
				if brush:
					ent.brushes.append(brush)
					brush = null
				elif ent:
					entities_data.append(ent)
					ent = null
			continue
		#endregion
		
		# Retrieve key value pairs
		if ent and line.begins_with("\""):
			var tokens: PackedStringArray = line.split("\" \"")
			var key: String = tokens[0].trim_prefix("\"")
			var value: String = tokens[1].trim_suffix("\"")
			
			#region BRUSH DATA
			if brush:
				if scope > 1:
					var uv: Transform2D = Transform2D.IDENTITY
					match key:
						"plane":
							tokens = value.replace("(", "").split(")", false)
							var points: PackedVector3Array
							points.resize(3) 
							for i in 3:
								tokens[i] = tokens[i].trim_prefix("(")
								var pts: PackedFloat64Array = tokens[i].split_floats(" ", false)
								var point: Vector3 = Vector3(pts[0], pts[1], pts[2])
								points[i] = point
							brush.planes.append(Plane(points[0], points[1], points[2]))
							continue
						"material":
							brush.textures.append(value)
							continue
						"uaxis", "vaxis":
							value = value.replace("[", "")
							var vals: PackedFloat64Array = value.replace("]", "").split_floats(" ", false)
							brush.uv_axes.append(Vector3(vals[0], vals[1], vals[2]))
							if key.begins_with("u"):
								uv.origin.x = vals[3]
								uv.x *= vals[4]
							else:
								uv.origin.y = vals[3]
								uv.y *= vals[4]
							continue
						"rotation":
							var r: float = deg_to_rad(value.to_float())
							# Can we rely on uvaxis always coming before rotation?
							uv.x = Vector2(cos(r), -sin(r)) * uv.x.length()
							uv.y = Vector2(sin(r), cos(r)) * uv.y.length()
							brush.uvs.append(uv)
							continue
			#endregion
			else:
				ent.properties[key] = value
				continue
	
	return entities_data
