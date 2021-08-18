extends Node

var websocketurl = "ws://test.mosquitto.org:8080/mqtt"

var roomname = "carrot"
var playerid = 0   # 1 if server
# mosquitto_sub -h test.mosquitto.org -v -t "carrot/#"

var serverstate_nextplayerid = 0
var serverstate_claimcodesforplayerids = { }

var clientstate_claimcode = ""
var clientstate_lastserverstatus = ""

func isserver():
	return (playerid == 1)
	
func _ready():
	$MQTT.binarymessages = true
	$MQTT.connect("received_message", self, "received_mqtt")

func serverstate_startmqttsignalling(lroomname):
	roomname = lroomname
	playerid = 1
	serverstate_claimcodesforplayerids = { }
	$MQTT.set_last_will(roomname+"/serverstatus", "off".to_ascii(), true)
	yield($MQTT.websocket_connect_to_server(), "completed")
	serverstate_allocatednextplayerid()

func clientstate_connecttomqttsignal(lroomname):
	roomname = lroomname
	playerid = 0
	serverstate_claimcodesforplayerids = null
	yield($MQTT.websocket_connect_to_server(), "completed")
	$MQTT.subscribe(roomname+"/serverstatus")

func serverstate_allocatednextplayerid():
	if serverstate_nextplayerid != 0:
		print("should mqtt.unsubscribehere")
	serverstate_nextplayerid = randi()
	$MQTT.subscribe("%s/servrec/%d" % [roomname, serverstate_nextplayerid])
	$MQTT.publish(roomname+"/serverstatus", ("nextid %d" % serverstate_nextplayerid).to_ascii(), true)

func mqs_session_description_created(type, data, cplayerid):
	print("mqs_session_description_created ", cplayerid, " ", type)
	var dpeer = get_tree().network_peer.get_peer(cplayerid)
	dpeer["connection"].set_local_description(type, data)
	var claimcode = serverstate_claimcodesforplayerids[cplayerid]
	var sd = ["session_description_created", claimcode, type, data]
	$MQTT.publish("%s/servsent/%d" % [roomname, cplayerid], var2bytes(sd))

func mqs_ice_candidate_created(mid_name, index_name, sdp_name, cplayerid):
	print("mqs_ice_candidate_created ", cplayerid, " ", mid_name)
	var claimcode = serverstate_claimcodesforplayerids[cplayerid]
	var sd = ["ice_candidate_created", claimcode, mid_name, index_name, sdp_name]
	$MQTT.publish("%s/servsent/%d" % [roomname, cplayerid], var2bytes(sd))

func mqc_session_description_created(type, data):
	print("mqc_session_description_created ", playerid, " ", type)
	var peer = get_tree().network_peer.get_peer(1)
	peer["connection"].set_local_description(type, data)
	var sd = ["session_description_created", clientstate_claimcode, type, data]
	$MQTT.publish("%s/servrec/%d" % [roomname, playerid], var2bytes(sd))

func mqc_ice_candidate_created(mid_name, index_name, sdp_name):
	print("mqc_ice_candidate_created ", playerid, " ", mid_name)
	var sd = ["ice_candidate_created", clientstate_claimcode, mid_name, index_name, sdp_name]
	$MQTT.publish("%s/servrec/%d" % [roomname, playerid], var2bytes(sd))


func received_mqtt(topic, msg):
	var stopic = topic.split("/")
		
	if len(stopic) == 2 and stopic[1] == "serverstatus":
		if clientstate_claimcode == "":
			assert (playerid == 0)
			clientstate_lastserverstatus = ""
			var smsg = msg.get_string_from_ascii().split(" ")
			if smsg[0] == "nextid":
				playerid = int(smsg[1])
				clientstate_claimcode = "claim%d"%randi()
				$MQTT.subscribe("%s/servsent/%d" % [roomname, playerid])
				var sd = ["requestoffer", clientstate_claimcode]
				$MQTT.publish("%s/servrec/%d" % [roomname, playerid], var2bytes(sd))
		else:
			assert (playerid > 1)
			clientstate_lastserverstatus = msg
		return
	
	if not (len(stopic) == 3 and ((stopic[1] == "servrec") or (stopic[1] == "servsent"))):
		return
	var cplayerid = int(stopic[2])
	var serverrecmsg = (playerid == 1)
	assert (serverrecmsg == (stopic[1] == "servrec"))
	var serversentmsg = not serverrecmsg
	assert (serversentmsg == (stopic[1] == "servsent"))
	var d = bytes2var(msg)
	var msgtype = d[0]
	var claimcode = d[1]
	if serversentmsg and (cplayerid != playerid):
		print("should have unsubscribed to playerid=%d" % cplayerid)
		return
		
	if msgtype == "requestoffer":
		assert (serverrecmsg)
		if not serverstate_claimcodesforplayerids.has(cplayerid):
			serverstate_claimcodesforplayerids[cplayerid] = claimcode
			var peer = WebRTCPeerConnection.new()
			peer.initialize({"iceServers": [ { "urls": ["stun:stun.l.google.com:19302"] } ] })
			peer.connect("session_description_created", self, "mqs_session_description_created", [cplayerid])
			peer.connect("ice_candidate_created", self, "mqs_ice_candidate_created", [cplayerid])
			get_tree().network_peer.add_peer(peer, cplayerid)
			var webrtcpeererror = peer.create_offer()
			print("peer create offer ", peer, "Error:", webrtcpeererror)
		else:
			var sd = ["offeralreadytaken", claimcode]
			$MQTT.publish("%s/servsent/%d" % [roomname, cplayerid], var2bytes(sd))

	elif serverrecmsg:
		if claimcode != serverstate_claimcodesforplayerids[cplayerid]:
			print("Mismatching claim code with ", cplayerid)
			return

	if msgtype == "offeralreadytaken":
		assert (serversentmsg)
		assert (playerid == cplayerid)
		#$MQTT.unsubscribe("%s/servsent/%d" % [roomname, playerid])
		print("should MQTT.unsubscribe")
		var sd = ["requestoffer", clientstate_claimcode]
		$MQTT.publish("%s/servrec/%d" % [roomname, playerid], var2bytes(sd))
		playerid == 0
		if clientstate_lastserverstatus != "":
			$MQTT.call_deferred("received_mqtt", "%s/serverstatus" % roomname, clientstate_lastserverstatus)
			clientstate_lastserverstatus = ""
			assert (playerid == 0)
		
	if msgtype == "session_description_created":
		print("rec ", ("client " if serversentmsg else "server "), d[0], " ", d[1], " ", d[2])
		if serversentmsg:
			assert (d[2] == "offer")
			var peer = WebRTCPeerConnection.new()
			peer.initialize({"iceServers": [ { "urls": ["stun:stun.l.google.com:19302"] } ] })
			peer.connect("session_description_created", self, "mqc_session_description_created")
			peer.connect("ice_candidate_created", self, "mqc_ice_candidate_created")
			peer.set_remote_description(d[2], d[3])

			var networkedmultiplayerclient = WebRTCMultiplayer.new()
			networkedmultiplayerclient.initialize(d[1], true)
			networkedmultiplayerclient.add_peer(peer, 1)
			get_tree().set_network_peer(networkedmultiplayerclient)
			print("networkedmultiplayerclient.is_network_server ", get_tree().is_network_server())
		else:
			assert (d[2] == "answer")
			var peer = get_tree().network_peer.get_peer(cplayerid)
			peer["connection"].set_remote_description(d[2], d[3])

	if msgtype == "ice_candidate_created":
		print("rec ", ("client " if serversentmsg else "server "), d[0], " ", d[1])
		var peer = get_tree().network_peer.get_peer(playerid if serversentmsg else 1)
		peer["connection"].add_ice_candidate(d[2], d[3], d[4])
