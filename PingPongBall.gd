extends KinematicBody2D

var velocity = Vector2(10, 5)
onready var PlayerConnections = get_node("../../NetworkGateway/PlayerConnections")

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
	var t1 = OS.get_ticks_msec()*0.001
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
				velocity = serverpongvelocity
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
			velocity = clientpongvelocity
			print("client pong update ", delta)
			clientpongst1 = 0.0
			clientpongupdate = true
			sendballupdate = true
	
	var ballcollision = false
	for i in range(3):
		var rel_vec = velocity*delta
		var k = move_and_collide(rel_vec)
		if k == null:
			break
		delta = k.remainder.length() / velocity.length()
		var tval = k.normal.tangent().dot(velocity)
		var vval = -k.normal.dot(velocity)*0.5 + k.normal.dot(k.collider_velocity)
		velocity = k.normal.tangent()*tval + k.normal*vval
		ballcollision = true
		if i == 2:
			print("bail out move_and_collides ", delta, velocity, k.normal)
	var rs = get_parent().rect_size
	if position.y > rs.y:
		position.y -= rs.y
		sendballupdate = true
	if position.y < 0:
		position.y += rs.y
		sendballupdate = true
		
	if sendballupdate or ballcollision:
		pingpongprevframet0 = t1
		if get_tree().is_network_server():
			rpc("serverpingpongballupdate", t1 + delta, position, velocity, clientpongupdate)
		elif ballcollision and PlayerConnections.ServerPlayer != null:
			var ServerPlayerFrame = PlayerConnections.ServerPlayer.get_node("PlayerFrame")
			var servertime = t1 + delta - ServerPlayerFrame.mintimestampoffset - ServerPlayerFrame.laglatency
			rpc("clientpingpongballupdate", servertime, position, velocity)

remote func serverpingpongballupdate(st1, sposition, svelocity, clientpongupdate):
	assert (get_tree().get_rpc_sender_id() == 1)
	if serverpongst1 == 0.0 or st1 <= serverpongst1:
		serverpongst1 = st1
		serverpongposition = sposition
		serverpongvelocity = svelocity
		Dserverclientpongupdate = clientpongupdate

remote func clientpingpongballupdate(st1, sposition, svelocity):
	assert (get_tree().is_network_server())
	if clientpongst1 == 0.0 or st1 >= clientpongst1:
		clientpongst1 = st1
		print("ss ", OS.get_ticks_msec()*0.001, " ", st1)
		clientpongposition = sposition
		clientpongvelocity = svelocity
	
		
	
