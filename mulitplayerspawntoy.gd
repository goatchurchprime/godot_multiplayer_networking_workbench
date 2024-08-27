extends RigidBody2D

func postspawnfunctionsetup(data):
	if data.has("letter"):
		$Label.text = data["letter"]
	if true or data.has("tangram"):
		var polygon = [ Vector2(0,0) ]
		polygon.append(Vector2(20,0))
		polygon.append(Vector2(0,20))
		$Polygon2D.polygon = PackedVector2Array(polygon)
		$Polygon2D.visible = true
	$Polygon2D.visible = false

	global_position = data["gpos"]
	$MultiplayerSynchronizer.rpc_config("set_multiplayer_authority", {"call_local":true, "rpc_mode":MultiplayerAPI.RPC_MODE_ANY_PEER})
