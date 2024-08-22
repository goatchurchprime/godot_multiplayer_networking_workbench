extends CharacterBody2D

var lvelocity = Vector2(10, 5)
@onready var PlayerConnections = get_node("../../NetworkGateway/PlayerConnections")

var pingpongprevframet0 = 0.0
var pingpongheartbeatseconds = 2.0

var serverpongst1 = 0.0
var serverpongposition = Vector2()
var serverpongvelocity = Vector2()
var Dserverclientpongupdate = false

var clientpongst1 = 0.0
var clientpongposition = Vector2()
var clientpongvelocity = Vector2()

var Dcdelta = 0.0
var Di = 0

func _physics_process(delta):
	var t1 = Time.get_ticks_msec()*0.001
	Dcdelta += delta
	Di += 1
	#if (Di % 60) == 0:
	#	print(OS.get_ticks_msec()*0.001 - Dcdelta)

	var sendballupdate = (t1 > pingpongprevframet0 + pingpongheartbeatseconds)
	
	if serverpongst1 != 0.0:
		if PlayerConnections.ServerPlayer != null:
			var ServerPlayerFrame = PlayerConnections.ServerPlayer.get_node("PlayerFrame")
			var servertime = t1 + delta - ServerPlayerFrame.mintimestampoffset - ServerPlayerFrame.laglatency
			if servertime > serverpongst1:
				delta = servertime - serverpongst1
				
				if Dserverclientpongupdate:
					print("client bounce back ", position, serverpongposition)
				
				position = serverpongposition
				lvelocity = serverpongvelocity
				print("Server pong update ", delta)
				serverpongst1 = 0.0
		else:
			serverpongst1 = 0.0

	var clientpongupdate = false
	if clientpongst1 != 0.0:
		var servertime = t1 + delta
		if servertime > clientpongst1:
			delta = servertime - clientpongst1
			position = clientpongposition
			lvelocity = clientpongvelocity
			print("client pong update ", delta)
			clientpongst1 = 0.0
			clientpongupdate = true
			sendballupdate = true
	
	var ballcollision = false
	for i in range(3):
		var rel_vec = lvelocity*delta
		var k = move_and_collide(rel_vec)
		if k == null:
			break
		delta = k.get_remainder().length() / lvelocity.length()
		var tval = k.get_normal().orthogonal().dot(lvelocity)
		var vval = -k.get_normal().dot(lvelocity)*0.5 + k.get_normal().dot(k.get_collider_velocity())
		lvelocity = k.get_normal().orthogonal()*tval + k.get_normal()*vval
		ballcollision = true
		if i == 2:
			print("bail out move_and_collides ", delta, lvelocity, k.get_normal())
	var rs = get_node("../MeshInstance2D").mesh.size
	if position.y > rs.y:
		position.y -= rs.y
		sendballupdate = true
	if position.y < 0:
		position.y += rs.y
		sendballupdate = true
	if position.x > rs.x:
		position.x -= rs.x
		sendballupdate = true
	if position.x < 0:
		position.x += rs.x
		sendballupdate = true
		
	if sendballupdate or ballcollision:
		pingpongprevframet0 = t1
		if multiplayer.is_server():
			rpc("serverpingpongballupdate", t1 + delta, position, lvelocity, clientpongupdate)
		elif ballcollision and PlayerConnections.ServerPlayer != null:
			var ServerPlayerFrame = PlayerConnections.ServerPlayer.get_node("PlayerFrame")
			var servertime = t1 + delta - ServerPlayerFrame.mintimestampoffset - ServerPlayerFrame.laglatency
			rpc("clientpingpongballupdate", servertime, position, lvelocity)

@rpc("authority", "call_remote", "reliable", 0)
func serverpingpongballupdate(st1, sposition, svelocity, clientpongupdate):
	assert (multiplayer.get_remote_sender_id() == 1)
	if serverpongst1 == 0.0 or st1 <= serverpongst1:
		serverpongst1 = st1
		serverpongposition = sposition
		serverpongvelocity = svelocity
		Dserverclientpongupdate = clientpongupdate

@rpc("any_peer", "call_remote", "reliable", 0)
func clientpingpongballupdate(st1, sposition, svelocity):
	#assert (not multiplayer.is_server())
	if clientpongst1 == 0.0 or st1 >= clientpongst1:
		clientpongst1 = st1
		print("ss ", Time.get_ticks_msec()*0.001, " ", st1)
		clientpongposition = sposition
		clientpongvelocity = svelocity
	
		
	
