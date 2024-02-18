@tool
@icon("res://addons/func_godot/icons/icon_godot_ranger.svg")
## Builds a new gamepack for NetRadiant Custom
class_name NetRadiantCustomGamePackConfig
extends Resource

## Button to export/update this gamepack's folder
@export var export_file: bool:
	get:
		return export_file
	set(new_export_file):
		if new_export_file != export_file:
			if Engine.is_editor_hint():
				do_export_file()

## Gamepack folder and file name. Must be lower case and must not contain special characters.
@export var gamepack_name : String = "func_godot"

## Name of the game in NetRadiant Custom's gamepack list.
@export var game_name : String = "FuncGodot"

## Name of the directory containing your maps, textures, shaders, etc...
@export var base_game_path : String = ""

## FGD resource to include with this gamepack. If using multiple FGD resources, this should be the master FGD that contains them in the `base_fgd_files` resource array.
@export var fgd_file : FuncGodotFGDFile = preload("res://addons/func_godot/fgd/func_godot_fgd.tres")

## [NetRadiantCustomShader] resources for shader file generation.
@export var netradiant_custom_shaders : Array[Resource] = [
	preload("res://addons/func_godot/game_config/netradiant_custom/netradiant_custom_shader_clip.tres"),
	preload("res://addons/func_godot/game_config/netradiant_custom/netradiant_custom_shader_skip.tres")
]

## Supported texture file types.
@export var texture_types : PackedStringArray = ["png", "jpg", "jpeg", "bmp", "tga"]

## Supported model file types.
@export var model_types : PackedStringArray = ["glb", "gltf", "obj"]

## Supported audio file types.
@export var sound_types : PackedStringArray = ["wav", "ogg"]

## Scale of entities in NetRadiant Custom
@export var default_scale : String = "1.0"

## Generates completed text for a .shader file.
func build_shader_text() -> String:
	var shader_text: String = ""
	for shader_res in netradiant_custom_shaders:
		shader_text += (shader_res as NetRadiantCustomShader).texture_path + "\n{\n"
		for shader_attrib in (shader_res as NetRadiantCustomShader).shader_attributes:
			shader_text += "\t" + shader_attrib + "\n"
		shader_text += "}\n"
	return shader_text

## Generates completed text for a .gamepack file.
func build_gamepack_text() -> String:
	var texturetypes_str: String = ""
	for texture_type in texture_types:
		texturetypes_str += texture_type
		if texture_type != texture_types[-1]:
			texturetypes_str += " "
	
	var modeltypes_str: String = ""
	for model_type in model_types:
		modeltypes_str += model_type
		if model_type != model_types[-1]:
			modeltypes_str += " "
	
	var soundtypes_str: String = ""
	for sound_type in sound_types:
		soundtypes_str += sound_type
		if sound_type != sound_types[-1]:
			soundtypes_str += " "
	
	var gamepack_text: String = """<?xml version="1.0"?>
<game
  type="q3"
  index="1" 
  name="%s"
  enginepath_win32="C:/%s/"
  engine_win32="%s.exe"
  enginepath_linux="/usr/local/games/%s/"
  engine_linux="%s"
  basegame="%s"
  basegamename="%s"
  unknowngamename="Custom %s modification"
  shaderpath="scripts"
  archivetypes="pk3"
  texturetypes="%s"
  modeltypes="%s"
  soundtypes="%s"
  maptypes="mapq1"
  shaders="quake3"
  entityclass="halflife"
  entityclasstype="fgd"
  entities="quake"
  brushtypes="quake"
  patchtypes="quake3"
  q3map2_type="quake3"
  default_scale="%s"
  common_shaders_name="Common"
  common_shaders_dir="common/"
/>
"""
	
	return gamepack_text % [
		game_name,
		game_name,
		gamepack_name,
		game_name,
		gamepack_name,
		base_game_path,
		game_name,
		game_name,
		texturetypes_str,
		modeltypes_str,
		soundtypes_str,
		default_scale
	]

## Exports or updates a folder in the /games directory, with an icon, .cfg, and all accompanying FGDs.
func do_export_file() -> void:
	if (FuncGodotProjectConfig.get_setting(FuncGodotProjectConfig.PROPERTY.MAP_EDITOR_GAME_PATH) as String).is_empty():
		printerr("Skipping export: Map Editor Game Path not set in Project Configuration")
		return
	
	var gamepacks_folder: String = FuncGodotProjectConfig.get_setting(FuncGodotProjectConfig.PROPERTY.NETRADIANT_CUSTOM_GAMEPACKS_FOLDER) as String
	if gamepacks_folder.is_empty():
		printerr("Skipping export: No NetRadiant Custom gamepacks folder")
		return
	
	# Make sure FGD file is set
	if !fgd_file:
		printerr("Skipping export: No FGD file")
		return
	
	# Make sure we're actually in the NetRadiant Custom gamepacks folder
	if DirAccess.open(gamepacks_folder + "/games") == null:
		printerr("Skipping export: No \'games\' folder. Is this the NetRadiant Custom gamepacks folder?")
		return
	
	# Create gamepack folders in case they do not exist
	var gamepack_dir_paths: Array = [
		gamepacks_folder + "/" + gamepack_name + ".game",
		gamepacks_folder + "/" + gamepack_name + ".game/scripts"
	]
	var err: Error
	
	for path in gamepack_dir_paths:
		if DirAccess.open(path) == null:
			print("Couldn't open " + path + ", creating...")
			err = DirAccess.make_dir_recursive_absolute(path)
			if err != OK:
				printerr("Skipping export: Failed to create directory")
				return
	
	var target_file_path: String
	var file: FileAccess
	
	# .gamepack
	target_file_path = gamepacks_folder + "/games/" + gamepack_name + ".game"
	print("Exporting NetRadiant Custom Gamepack to ", target_file_path)
	file = FileAccess.open(target_file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(build_gamepack_text())
		file.close()
	else:
		printerr("Error: Could not modify " + target_file_path)
	
	# .shader
	target_file_path = gamepacks_folder + "/" + gamepack_name + ".game/scripts/" + gamepack_name + ".shader"
	print("Exporting NetRadiant Custom Shader to ", target_file_path)
	file = FileAccess.open(target_file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(build_shader_text())
		file.close()
	else:
		printerr("Error: Could not modify " + target_file_path)
	
	# shaderlist.txt
	target_file_path = gamepacks_folder + "/" + gamepack_name + ".game/scripts/shaderlist.txt"
	print("Exporting NetRadiant Custom Default Buld Menu to ", target_file_path)
	file = FileAccess.open(target_file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(gamepack_name)
		file.close()
	else:
		printerr("Error: Could not modify " + target_file_path)
	
	# default_build_menu.xml
	target_file_path = gamepacks_folder + "/" + gamepack_name + ".game/default_build_menu.xml"
	print("Exporting NetRadiant Custom Default Buld Menu to ", target_file_path)
	file = FileAccess.open(target_file_path, FileAccess.WRITE)
	if file != null:
		file.store_string("<?xml version=\"1.0\"?><project version=\"2.0\"></project>")
		file.close()
	else:
		printerr("Error: Could not modify " + target_file_path)
	
	# FGD
	var export_fgd : FuncGodotFGDFile = fgd_file.duplicate()
	export_fgd.do_export_file(true, gamepacks_folder + "/" + gamepack_name + ".game/" + base_game_path)
	print("Export complete\n")