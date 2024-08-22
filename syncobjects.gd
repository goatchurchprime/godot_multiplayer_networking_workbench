extends Node2D

@rpc("any_peer", "call_local")
func ssss(me):
	print("ssss ", me, "  ll ", multiplayer.get_unique_id(), " ", $RigidBody2D.get_multiplayer_authority(), " :", multiplayer.get_remote_sender_id())

var spawntoyscene = load("res://mulitplayerspawntoy.tscn")
	
# The MultiplayerSynchronizer synchronizes in the direction of the authority to the peers
func _ready():
	$MultiplayerSynchronizer.rpc_config("set_multiplayer_authority", {"call_local":true, "rpc_mode":MultiplayerAPI.RPC_MODE_ANY_PEER})
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	$MultiplayerSpawner.set_spawn_function(spawnthistoy)
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

func interactcurrenttoy(pressed):
	if pressed and relmouse == null and currentmousetoy != null:
		relmouse = get_global_mouse_position() - currentmousetoy.get_global_position()
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

func spawnthistoy(data):
	print("spawnthistoy ", data)
	var k = spawntoyscene.instantiate()
	k.get_node("Label").text = data["letter"]
	k.get_node("MultiplayerSynchronizer").rpc_config("set_multiplayer_authority", {"call_local":true, "rpc_mode":MultiplayerAPI.RPC_MODE_ANY_PEER})
	return k

var xx = 0
var letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
func spawnnexttoy(gpos):
	var h = $MultiplayerSpawner.spawn({"letter":letters[xx]})
	xx += 1
	h.global_position = gpos
#	h.mouse_entered.connect(mouseenter.bind(h))
	h.mouse_exited.connect(mouseexit.bind(h))
	return

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_U:
		prints($spawnedtoy.get_multiplayer_authority(), multiplayer.get_unique_id())
		$spawnedtoy.position.x += 20
	if event is InputEventKey and event.pressed and event.keycode == KEY_Y:
		prints($spawnedtoy.get_multiplayer_authority(), multiplayer.get_unique_id())
		$spawnedtoy.position.x -= 15
	if event is InputEventKey and event.pressed and event.keycode == KEY_A:
#		$RigidBody2D.rpc(set_multiplayer_authority(multiplayer.get_unique_id())
		print("calling out to ssss")
		await get_tree().create_timer(0.01)
		rpc("ssss", "mme %d" % multiplayer.get_unique_id())
		#$RigidBody2D.rpc("set_multiplayer_authority", multiplayer.get_unique_id())
		$MultiplayerSynchronizer.rpc("set_multiplayer_authority", multiplayer.get_unique_id())

	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		spawnnexttoy(get_global_mouse_position())

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		interactcurrenttoy(event.pressed)
		#get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion:
		motioncurrenttoy(event.global_position)
	