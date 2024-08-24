extends Node2D

@rpc("any_peer", "call_local")
func ssss(me):
	print("ssss ", me, "  ll ", multiplayer.get_unique_id(), " ", $RigidBody2D.get_multiplayer_authority(), " :", multiplayer.get_remote_sender_id())

var spawntoyscene = load("res://mulitplayerspawntoy.tscn")
	
# The MultiplayerSynchronizer synchronizes in the direction of the authority to the peers
func _ready():
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	$MultiplayerSpawner.set_spawn_function(spawnfunction)
	$MultiplayerSpawner.rpc_config("spawn", {"call_local":true, "rpc_mode":MultiplayerAPI.RPC_MODE_ANY_PEER})
	spawnnexttoy(Vector2i(300, 700))


var currentmousetoy = null
var relmouse = null
var topzindex = 2
func mouseenter(mousetoy):
	print("ment ", mousetoy)
	if relmouse == null: 
			# need a more complex system keeping track of all the ins
			# and what's highest
			# or doing a ray collision check when we click 
		if currentmousetoy != null:
			currentmousetoy.get_node("MouseIn").visible = false
		currentmousetoy = mousetoy
		currentmousetoy.get_node("MouseIn").visible = true

func mouseexit(mousetoy):
	print(" mexit ", mousetoy)
	mousetoy.get_node("MouseIn").visible = false
	if currentmousetoy == mousetoy:
		if relmouse == null: 
			currentmousetoy.get_node("MouseIn").visible = false
			currentmousetoy = null

func interactcurrenttoy(pressed, gpos):
	if pressed and relmouse == null and currentmousetoy != null:
		relmouse = gpos - currentmousetoy.get_global_position()
		if currentmousetoy.z_index < topzindex:
			topzindex += 1
			currentmousetoy.z_index = topzindex
		if currentmousetoy.get_node("MultiplayerSynchronizer").get_multiplayer_authority() != multiplayer.get_unique_id():
			currentmousetoy.get_node("MultiplayerSynchronizer").rpc("set_multiplayer_authority", multiplayer.get_unique_id())

	elif relmouse != null and not pressed:
		relmouse = null

func motioncurrenttoy(gpos):
	if currentmousetoy != null and relmouse != null:
		currentmousetoy.global_position = gpos - relmouse

var xx = 0
var letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
func spawnfunction(data):
	print(" -- spawnfunction ", data, multiplayer.get_unique_id(), " ", multiplayer.is_server())
	var k = spawntoyscene.instantiate()
	if data.has("letter"):
		k.get_node("Label").text = data["letter"]
	else:
		k.get_node("Label").text = letters[xx]
		xx += 1
	k.global_position = data["gpos"]
	k.get_node("MultiplayerSynchronizer").rpc_config("set_multiplayer_authority", {"call_local":true, "rpc_mode":MultiplayerAPI.RPC_MODE_ANY_PEER})
	return k

func spawnnexttoy(gpos):
	print("  ;spawnnexttoy ", gpos, " ", letters[xx], " ", $MultiplayerSpawner.get_spawn_function(), " ", multiplayer.is_server(), "  ", $MultiplayerSpawner.get_multiplayer_authority())
	var hh = $MultiplayerSpawner.rpc_id($MultiplayerSpawner.get_multiplayer_authority(), "spawn", {"letter":letters[xx], "gpos":gpos})
	#var hh = $MultiplayerSpawner.spawn({"letter":letters[xx], "gpos":gpos})
	print(" spawnnexttoy ", hh)
	xx += 1
	#hh.global_position = gpos
	return

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_U:
		prints($spawnedtoy.get_multiplayer_authority(), multiplayer.get_unique_id())
		$spawnedtoy.position.x += 20
	if event is InputEventKey and event.pressed and event.keycode == KEY_Y:
		prints($spawnedtoy.get_multiplayer_authority(), multiplayer.get_unique_id())
		$spawnedtoy.position.x -= 15

	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		spawnnexttoy(get_global_mouse_position())

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pp = get_node("../Players").get_child(0)
		print("ppp ", pp, pp.get_overlapping_areas(), pp.get_overlapping_bodies())
		var pq = pp.get_overlapping_bodies()
		if len(pq) != 0:
			currentmousetoy = pq[0]

		interactcurrenttoy(event.pressed, event.global_position)
		#get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion:
		motioncurrenttoy(event.global_position)
	
