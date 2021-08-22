extends Node

# MQTT client implementation in GDScript
# Based on https://github.com/pycom/pycom-libraries/blob/master/lib/mqtt/mqtt.py
# and initial work by Alex J Lennon <ajlennon@dynamicdevices.co.uk>

# mosquitto_sub -h test.mosquitto.org -v -t "metest/#"
# mosquitto_pub -h test.mosquitto.org -t "metest/retain" -m "retained message" -r

export var server = "test.mosquitto.org"
export var port = 1883
export var client_id = ""
#var websocketurl = "ws://node-red.dynamicdevices.co.uk:1880/ws/test"
var websocketurl = "ws://test.mosquitto.org:8080/mqtt"
#var websocketurl = "ws://echo.websocket.org"
	
var socket = null
var sslsocket = null
var websocketclient = null
var websocket = null
var binarymessages = false

var ssl = false
var ssl_params = null
var pid = 0
var user = null
var pswd = null
var keepalive = 0
var lw_topic = null
var lw_msg = null
var lw_qos = 0
var lw_retain = false

signal received_message(topic, message)


var receivedbuffer : PoolByteArray = PoolByteArray()

func receivedbufferlength():
	#return socket.get_available_bytes()
	return receivedbuffer.size()
	
func YreceivedbuffernextNbytes(n):
	yield(get_tree(), "idle_frame")
	if n == 0:
		return PoolByteArray()
	while receivedbufferlength() < n:
		yield(get_tree().create_timer(0.1), "timeout")
	#var sv = socket.get_data(n)
	#assert (sv[0] == 0)  # error
	#return sv[1]
	var v = receivedbuffer.subarray(0, n-1)

	# make this a longer buffer so the front doesn't have to be trimmed off too often
	receivedbuffer = receivedbuffer.subarray(n, -1) if n != receivedbuffer.size() else PoolByteArray()
	return v

func Yreceivedbuffernext2byteWord():
	var v = yield(YreceivedbuffernextNbytes(2), "completed")
	return (v[0]<<8) + v[1]

func Yreceivedbuffernextbyte():
	return yield(YreceivedbuffernextNbytes(1), "completed")[0]

func senddata(data):
	if socket != null:
		socket.put_data(data)
	elif sslsocket != null:
		sslsocket.put_data(data)
	elif websocket != null:
		#print("putting packet ", Array(data))
		var E = websocket.put_packet(data)
		assert (E == 0)
	
var in_wait_msg = false
func _process(delta):
	if socket != null and socket.is_connected_to_host():
		var n = socket.get_available_bytes()
		if n != 0:
			var sv = socket.get_data(n)
			assert (sv[0] == 0)  # error code
			receivedbuffer.append_array(sv[1])
			
	elif sslsocket != null:
		if sslsocket.status == StreamPeerSSL.STATUS_CONNECTED or sslsocket.status == StreamPeerSSL.STATUS_HANDSHAKING:
			sslsocket.poll()
			var n = sslsocket.get_available_bytes()
			if n != 0:
				var sv = sslsocket.get_data(n)
				assert (sv[0] == 0)  # error code
				receivedbuffer.append_array(sv[1])

	elif websocketclient != null:
		websocketclient.poll()
		while websocket.get_available_packet_count() != 0:
			print("Packets ", websocket.get_available_packet_count())
			receivedbuffer.append_array(websocket.get_packet())
			#print("nnn ", Array(receivedbuffer))

	if in_wait_msg:
		return
	if receivedbufferlength() <= 0:
		return
	in_wait_msg = true
	while receivedbufferlength() > 0:
		yield(wait_msg(), "completed")
	in_wait_msg = false



func websocketexperiment():
	websocketclient = WebSocketClient.new()
	var URL = "ws://node-red.dynamicdevices.co.uk:1880/ws/test"
	var E = websocketclient.connect_to_url(URL)
	if E != 0:
		print("Err: ", E)
	websocket = websocketclient.get_peer(1)
	while not websocket.is_connected_to_host():
		websocketclient.poll()
		print("connecting to host")
		yield(get_tree().create_timer(0.1), "timeout")

	for i in range(5):
		var E2 = websocket.put_packet(PoolByteArray([100,101,102,103,104,105]))
		print("Ersr putpacket: ", E2)
		yield(get_tree().create_timer(0.5), "timeout")


func _ready():
	if client_id == "":
		randomize()
		client_id = str(randi())

	if get_name() == "test_mqtt1":
		websocketexperiment()
		
	if get_name() == "test_mqtt":
		var metopic = "metest/"
		set_last_will(metopic+"status", "stopped", true)
		#if yield(connect_to_server(), "completed"):
		if yield(websocket_connect_to_server(), "completed"):
			publish(metopic+"status", "connected", true)
		else:
			print("mqtt failed to connect")
		##connect("received_message", self, "received_mqtt")
		subscribe(metopic+"retain")
		subscribe(metopic+"time")
		for i in range(5):
			print("ii", i)
			yield(get_tree().create_timer(0.5), "timeout")
			publish(metopic+"time", "t%d" % i)

func Y_recv_len():
	var n = 0
	var sh = 0
	var b
	while 1:
		b = yield(Yreceivedbuffernextbyte(), "completed")
		n |= (b & 0x7f) << sh
		if not b & 0x80:
			return n
		sh += 7

func set_last_will(topic, msg, retain=false, qos=0):
	assert((0 <= qos) and (qos <= 2))
	assert(topic)
	self.lw_topic = topic.to_ascii()
	self.lw_msg = msg if binarymessages else msg.to_ascii()
	self.lw_qos = qos
	self.lw_retain = retain

func firstmessagetoserver():
	var clean_session = true
	var msg = PoolByteArray()
	msg.append(0x10);
	msg.append(0x00);
	msg.append(0x00);
	msg.append(0x04);
	msg.append_array("MQTT".to_ascii());
	msg.append(0x04);
	msg.append(0x02);
	msg.append(0x00);
	msg.append(0x00);

	msg[1] = 10 + 2 + len(self.client_id)
	msg[9] = (1<<1) if clean_session else 0
	if self.user != null:
		msg[1] += 2 + len(self.user) + 2 + len(self.pswd)
		msg[9] |= 0xC0
	if self.keepalive:
		assert(self.keepalive < 65536)
		msg[10] |= self.keepalive >> 8
		msg[11] |= self.keepalive & 0x00FF
	if self.lw_topic:
		msg[1] += 2 + len(self.lw_topic) + 2 + len(self.lw_msg)
		msg[9] |= 0x4 | (self.lw_qos & 0x1) << 3 | (self.lw_qos & 0x2) << 3
		msg[9] |= 1<<5 if self.lw_retain else 0

	msg.append(len(self.client_id) >> 8)
	msg.append(self.client_id.length() & 0xFF)
	msg.append_array(self.client_id.to_ascii())
	if self.lw_topic:
		msg.append(len(self.lw_topic) >> 8)
		msg.append(len(self.lw_topic) & 0xFF)
		msg.append_array(self.lw_topic)
		msg.append(len(self.lw_msg) >> 8)
		msg.append(len(self.lw_msg) & 0xFF)
		msg.append_array(self.lw_msg)
	if self.user != null:
		msg.append(self.user.length() >> 8)
		msg.append(self.user.length() & 0xFF)
		msg.append_array(self.user.to_ascii())
		msg.append(self.pswd.length() >> 8)
		msg.append(self.pswd.length() & 0xFF)
		msg.append_array(self.pswd.to_ascii())
	return msg

func connect_to_server(usessl=false):
	assert (server != "")
	if client_id == "":
		client_id = "rr%d" % randi()
	in_wait_msg = true

	socket = StreamPeerTCP.new()
	print("Connecting to %s:%s" % [self.server, self.port])
	socket.connect_to_host(self.server, self.port)
	while not socket.is_connected_to_host():
		yield(get_tree().create_timer(0.2), "timeout")
	while socket.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		yield(get_tree().create_timer(0.2), "timeout")

	if usessl:
		sslsocket = StreamPeerSSL.new()
		var E3 = sslsocket.connect_to_stream(socket) 
		print("EE3 ", E3)
		
	print("Connected to mqtt broker ", self.server)

	var msg = firstmessagetoserver()
	senddata(msg)
	
	var data = yield(YreceivedbuffernextNbytes(4), "completed")
	if data == null:
		socket = null
		in_wait_msg = false
		return false
		
	assert(data[0] == 0x20 and data[1] == 0x02)
	if data[3] != 0:
		print("MQTT exception ", data[3])
		in_wait_msg = false
		return false

	#return data[2] & 1
	in_wait_msg = false
	return true

func websocket_connect_to_server():
	assert (server != "")
	if client_id == "":
		client_id = "rr%d" % randi()
	in_wait_msg = true

	websocketclient = WebSocketClient.new()
	#websocketurl = "ws://node-red.dynamicdevices.co.uk:1880/ws/test"
	var E = websocketclient.connect_to_url(websocketurl, PoolStringArray(["mqttv3.1"])) # , false, PoolStringArray(headers))	
	#var E = websocketclient.connect_to_url(websocketurl)	
	if E != 0:
		print("websocketclient.connect_to_url Err: ", E)

	websocket = websocketclient.get_peer(1)
	var Dcd = 20
	while not websocket.is_connected_to_host():
		websocketclient.poll()
		Dcd -= 1
		if Dcd == 0:
			print("connecting to host")
			Dcd = 20
		yield(get_tree().create_timer(0.1), "timeout")


	var msg = firstmessagetoserver()

	yield(get_tree().create_timer(0.5), "timeout")
	print("Connected to mqtt broker ", self.server)

	
	#print(Array(msg))
	#msg = PoolByteArray([16,46,0,4,77,81,84,84,4,38,0,0,0,10,49,54,49,57,53,53,53,52,53,49,0,13,109,101,116,101,115,116,47,115,116,97,116,117,115,0,7,115,116,111,112,112,101,100])
	#yield(get_tree().create_timer(0.5), "timeout")
	senddata(msg)
	#var E1 = websocket.put_packet(msg)
	#websocketclient.poll()
	#assert (E1 == 0)
	
	#while true:
	#	websocketclient.poll()
	#	print("packets available ", websocket.get_available_packet_count())
	#	if websocket.get_available_packet_count() != 0:
	#		print(Array(websocket.get_packet()))
	#	yield(get_tree().create_timer(0.1), "timeout")

	
	var data = yield(YreceivedbuffernextNbytes(4), "completed")
	print("dddd ", data)
	if data == null:
		socket = null
		websocket = null
		websocketclient = null
		in_wait_msg = false
		return false
		
	assert(data[0] == 0x20 and data[1] == 0x02)
	if data[3] != 0:
		print("MQTT exception ", data[3])
		in_wait_msg = false
		return false

	#return data[2] & 1
	in_wait_msg = false
	return true

func is_connected_to_server():
	if socket != null and socket.is_connected_to_host():
		return true
	if websocket != null and websocket.is_connected_to_host():
		return true
	return false


func disconnect_from_server():
	#senddata(PoolByteArray([0xE0, 0x00]))
	if socket != null:
		socket.disconnect_from_host()
		socket = null
	if websocketclient != null:
		websocketclient.disconnect_from_host()
		websocketclient = null
		websocket = null

	
func ping():
	senddata(PoolByteArray([0xC0, 0x00]))

func publish(topic, msg, retain=false, qos=0):
	if not binarymessages:
		msg = msg.to_ascii()
	topic = topic.to_ascii()
	
	#print("publishing ", topic, " ", msg)
	if socket != null:
		if not socket.is_connected_to_host():
			return
	elif websocket != null:
		if not websocket.is_connected_to_host():
			return
	else:
		return

	var pkt = PoolByteArray()
	# Must be an easier way of doing this...
	pkt.append(0x30);
	pkt.append(0x00);
		
	pkt[0] |= ((1<<1) if qos else 0) | (1 if retain else 0)
	var sz = 2 + len(topic) + len(msg)
	if qos > 0:
		sz += 2
	assert(sz < 2097152)
	var i = 1
	while sz > 0x7f:
		pkt[i] = (sz & 0x7f) | 0x80
		sz >>= 7
		i += 1
		if i + 1 > len(pkt):
			pkt.append(0x00);
	pkt[i] = sz
	
	pkt.append(len(topic) >> 8)
	pkt.append(len(topic) & 0xFF)
	pkt.append_array(topic)

	if qos > 0:
		self.pid += 1
		pkt.append(self.pid >> 8)
		pkt.append(self.pid & 0xFF)

	pkt.append_array(msg)
	senddata(pkt)
	
	if qos == 1:
		while 1:
			var op = self.wait_msg()
			if op == 0x40:
				sz = yield(Yreceivedbuffernextbyte(), "completed")
				assert(sz == 0x02)
				var rcv_pid = yield(Yreceivedbuffernext2byteWord(), "completed")
				if self.pid == rcv_pid:
					return
	elif qos == 2:
		assert(0)

func subscribe(topic, qos=0):
	self.pid += 1
	topic = topic.to_ascii()

	var msg = PoolByteArray()
	# Must be an easier way of doing this...
	msg.append(0x82);
	var length = 2 + 2 + len(topic) + 1
	msg.append(length)
	msg.append(self.pid >> 8)
	msg.append(self.pid & 0xFF)
	msg.append(len(topic) >> 8)
	msg.append(len(topic) & 0xFF)
	msg.append_array(topic)
	msg.append(qos);
	
	senddata(msg)
	
	while 0:
		var op = self.wait_msg()
		if op == 0x90:
			var data = yield(YreceivedbuffernextNbytes(4), "completed")
			assert(data[1] == (self.pid >> 8) and data[2] == (self.pid & 0x0F))
			if data[3] == 0x80:
				print("MQTT exception ", data[3])
				return false
			return true

	

# Wait for a single incoming MQTT message and process it.
# Subscribed messages are delivered to a callback previously
# set by .set_callback() method. Other (internal) MQTT
# messages processed internally.
func wait_msg():
	yield(get_tree(), "idle_frame") 
	if receivedbufferlength() <= 0:
		return
		
	var res = yield(Yreceivedbuffernextbyte(), "completed")

	if res == null:
		return null
	if res == 0:
		return false # raise OSError(-1)
	if res == 0xD0:  # PINGRESP
		var sz = yield(Yreceivedbuffernextbyte(), "completed")
		assert(sz == 0)
		return null
	var op = res
	if op & 0xf0 != 0x30:
		return op
	var sz = yield(Y_recv_len(), "completed")
	var topic_len = yield(Yreceivedbuffernext2byteWord(), "completed")
	var data = yield(YreceivedbuffernextNbytes(topic_len), "completed")
	var topic = data.get_string_from_ascii()
	sz -= topic_len + 2
	var pid
	if op & 6:
		pid = yield(Yreceivedbuffernext2byteWord(), "completed")
		sz -= 2
	data = yield(YreceivedbuffernextNbytes(sz), "completed")
	var msg = data if binarymessages else data.get_string_from_ascii()
	
	emit_signal("received_message", topic, msg)
	print("Received message", [topic, msg.substr(0, 30)])
	
#	self.cb(topic, msg)
	if op & 6 == 2:
		var pkt = PoolByteArray()
		pkt.append(0x40);
		pkt.append(0x02);
		pkt.append(pid >> 8);
		pkt.append(pid & 0xFF);
		socket.write(pkt)
	elif op & 6 == 4:
		assert(0)

