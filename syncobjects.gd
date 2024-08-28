extends Node2D

@rpc("any_peer", "call_local")
func ssss(me):
	print("ssss ", me, "  ll ", multiplayer.get_unique_id(), " ", $RigidBody2D.get_multiplayer_authority(), " :", multiplayer.get_remote_sender_id())

@onready var NetworkGateway = find_parent("Main").get_node("NetworkGateway")

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
func _on_local_player_body_entered(mousetoy):
	pass # Replace with function body.
	print("ment ", mousetoy)
	if relmouse == null: 
			# need a more complex system keeping track of all the ins
			# and what's highest
			# or doing a ray collision check when we click 
		if currentmousetoy != null:
			currentmousetoy.get_node("MouseIn").visible = false
		currentmousetoy = mousetoy
		currentmousetoy.get_node("MouseIn").visible = true

func _on_local_player_body_exited(mousetoy):
	pass # Replace with function body.
	print(" mexit ", mousetoy)
	mousetoy.get_node("MouseIn").visible = false
	if currentmousetoy == mousetoy:
		if relmouse == null: 
			currentmousetoy.get_node("MouseIn").visible = false
			currentmousetoy = null



func interactcurrenttoy(pressed, gpos):
	if pressed and relmouse == null and currentmousetoy != null:
		relmouse = NetworkGateway.PlayerConnections.LocalPlayer.global_position - currentmousetoy.get_global_position()
		if currentmousetoy.z_index < topzindex:
			topzindex += 1
			currentmousetoy.z_index = topzindex
		if currentmousetoy.get_node("MultiplayerSynchronizer").get_multiplayer_authority() != multiplayer.get_unique_id():
			currentmousetoy.get_node("MultiplayerSynchronizer").rpc("set_multiplayer_authority", multiplayer.get_unique_id())

	elif relmouse != null and not pressed:
		relmouse = null


func _process(delta):
	if currentmousetoy != null and relmouse != null:
		currentmousetoy.global_position = NetworkGateway.PlayerConnections.LocalPlayer.global_position - relmouse


var xx = 0
var letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
func spawnfunction(data):
	print(" -- spawnfunction ", data, multiplayer.get_unique_id(), " ", multiplayer.is_server())
	var k = spawntoyscene.instantiate()
	if data.has("letter"):
		if data["letter"] == "*next":
			data["letter"] = letters[xx]
			xx += 1
	k.postspawnfunctionsetup(data)
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
		NetworkGateway.PlayerConnections.LocalPlayer.PF_processlocalavatarposition(0) # force update on position
		var pq = NetworkGateway.PlayerConnections.LocalPlayer.get_overlapping_bodies()
		print("ppp ", NetworkGateway.PlayerConnections.LocalPlayer, pq, NetworkGateway.PlayerConnections.LocalPlayer.get_overlapping_bodies())
		if len(pq) != 0:
			currentmousetoy = pq[0]

		interactcurrenttoy(event.pressed, event.global_position)
		#get_viewport().set_input_as_handled()
	
