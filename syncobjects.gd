extends Node2D

@rpc("any_peer", "call_local")
func ssss(me):
	print("ssss ", me, "  ll ", multiplayer.get_unique_id(), " ", $RigidBody2D.get_multiplayer_authority(), " :", multiplayer.get_remote_sender_id())
	
# The MultiplayerSynchronizer synchronizes in the direction of the authority to the peers
func _ready():
	$MultiplayerSynchronizer.rpc_config("set_multiplayer_authority", {"call_local":true, "rpc_mode":MultiplayerAPI.RPC_MODE_ANY_PEER})
	$spawnedtoy.mouse_entered.connect(mouseenter.bind("thinkg"))
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)

func Dmouseenter():
	print("sdfs")
func mouseenter(eekl):
	print("dasda ", eekl)
	
var xx = 0
var letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
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
		xx += 1
		var kk = load("res://mulitplayerspawntoy.tscn")
		print(kk)
		var k = kk.instantiate()
		k.position.x = xx*30  
		k.position.y = 150  
		k.get_node("Label").text = letters[xx]
		add_child(k, true)
		print(k)

#	if event is InputEventMouseMotion:
#		if $spawnedtoy.relmouse == null:
#			$spawnedtoy.global_position = event.global_position
		#get_viewport().set_input_as_handled()

func _on_spawnedtoy_input_event(viewport, event, shape_idx):
	pass
	if event is not InputEventMouseMotion:
		print(viewport, event, shape_idx)


func _on_spawnedtoy_mouse_entered():
	print("mmm:")
	
