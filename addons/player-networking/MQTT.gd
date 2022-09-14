extends Node

# MQTT client implementation in GDScript
# Based on https://github.com/pycom/pycom-libraries/blob/master/lib/mqtt/mqtt.py
# and initial work by Alex J Lennon <ajlennon@dynamicdevices.co.uk>

# mosquitto_sub -h test.mosquitto.org -v -t "metest/#"
# mosquitto_pub -h test.mosquitto.org -t "metest/retain" -m "retained message" -r

export var client_id = ""
	
var socket = null
var sslsocket = null
var websocketclient = null
var websocket = null

var regexbrokerurl = RegEx.new()

var binarymessages = false

var ssl = false
var ssl_params = null
var pid = 0
var user = null
var pswd = null
var keepalive = 120
var pinginterval = 30
var lw_topic = null
var lw_msg = null
var lw_qos = 0
var lw_retain = false

signal received_message(topic, message)
signal broker_connected()
signal broker_disconnected()


var receivedbuffer : PoolByteArray = PoolByteArray()

func receivedbufferlength():
	return receivedbuffer.size()
	
func YreceivedbuffernextNbytes(n):
	yield(get_tree(), "idle_frame")
	if n == 0:
		return PoolByteArray()
	var Dcount = 0
	while receivedbufferlength() < n:
		yield(get_tree().create_timer(0.1), "timeout")
		Dcount += 1
		if (Dcount % 20) == 0 and (n == 4):
			print("received hanging on 4 bytes return")
		if socket == null and websocket == null:
			return PoolByteArray([0,0,0,0])
			
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
	var E = 0
	if socket != null:
		E = socket.put_data(data)
	elif sslsocket != null:
		E = sslsocket.put_data(data)
	elif websocket != null:
		E = websocket.put_packet(data)
	if E != 0:
		print("bad senddata packet E=", E)
	
var in_wait_msg = false
var pingticksnext0 = 0
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

	if pingticksnext0 < OS.get_ticks_msec():
		ping()
		pingticksnext0 = OS.get_ticks_msec() + pinginterval*1000

	if in_wait_msg:
		return
	if receivedbufferlength() <= 0:
		return

	wait_msg()
#	in_wait_msg = true
#	while receivedbufferlength() > 0:
#		yield(Ywait_msg(), "completed")
#	in_wait_msg = false

func _ready():
	regexbrokerurl.compile('^(wss://|ws://|ssl://)?([^:\\s]+)(:\\d+)?(/\\S*)?$')
	if client_id == "":
		randomize()
		client_id = str(randi())

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
	msg.append(0x3C);

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

func cleanupsockets(retval=false):
	print("cleanupsockets")
	if socket:
		if sslsocket:
			sslsocket = null
		socket.disconnect_from_host()
		socket = null
	else:
		assert (sslsocket == null)

	if websocketclient:
		if websocket:
			websocket = null
		websocketclient.disconnect_from_host()
		websocketclient = null
	else:
		assert (websocket == null)
		
	in_wait_msg = false
	return retval
	
func connect_to_broker(brokerurl):
	# regexbrokerurl.compile('^(wss://|ws://|ssl://)?([^:\\s]+)(:\\d+)?(/\\S*)?$')
	var brokermatch = regexbrokerurl.search(brokerurl)
	if brokermatch == null:
		print("unrecognized brokerurl pattern:", brokerurl)
		return cleanupsockets(false)
	var brokercomponents = brokermatch.strings
	var brokerprotocol = brokercomponents[1]
	var brokerserver = brokercomponents[2]
	var iswebsocket = (brokerprotocol == "ws://" or brokerprotocol == "wss://")
	var isssl = (brokerprotocol == "ssl://" or brokerprotocol == "wss://")
	var brokerport = ((8081 if isssl else 8080) if iswebsocket else (8884 if isssl else 1883))
	if brokercomponents[3]:
		brokerport = int(brokercomponents[3].substr(1)) 
	var brokerpath = brokercomponents[4] if brokercomponents[4] else "/"
	
	if client_id == "":
		client_id = "rr%d" % randi()
	in_wait_msg = true

	var Dcount = 0
	if iswebsocket:
		websocketclient = WebSocketClient.new()
		websocketclient.verify_ssl = isssl
		var websocketurl = ("wss://" if isssl else "ws://") + brokerserver + ":" + str(brokerport) + brokerpath
		print("Connecting to websocketurl: ", websocketurl)
		var E = websocketclient.connect_to_url(websocketurl, PoolStringArray(["mqttv3.1"]))
		if E != 0:
			print("websocketclient.connect_to_url Err: ", E)
			return cleanupsockets(false)
			
		websocket = websocketclient.get_peer(1)
		while not websocket.is_connected_to_host():
			websocketclient.poll()
			if (Dcount % 20) == 0:
				print("connecting to websocket host")
			Dcount += 1
			yield(get_tree().create_timer(0.1), "timeout")
			if websocket == null:
				return cleanupsockets(false)

	else:
		socket = StreamPeerTCP.new()
		print("Connecting to %s:%s" % [brokerserver, brokerport])
		socket.connect_to_host(brokerserver, brokerport)
		yield(get_tree().create_timer(0.1), "timeout")
		while not socket.is_connected_to_host() and (socket.get_status() != StreamPeerTCP.STATUS_CONNECTED):
			if (Dcount % 20) == 0:
				print("connecting to socket host")
			Dcount += 1
			yield(get_tree().create_timer(0.1), "timeout")
			if socket == null:
				return cleanupsockets(false)

		if isssl:
			sslsocket = StreamPeerSSL.new()
			var E3 = sslsocket.connect_to_stream(socket)
			if E3 != 0:
				print("bad sslsocket.connect_to_stream E=", E3)
				return cleanupsockets(false)
		
	print("Connected to mqtt broker ", brokerurl)
	var msg = firstmessagetoserver()
	senddata(msg)
	
	var data = yield(YreceivedbuffernextNbytes(4), "completed")
	if data == null:
		print("failed on first message")
		return cleanupsockets(false)
		
	if not (data[0] == 0x20 and data[1] == 0x02):
		print("MQTT first message bad return ", data)
		return cleanupsockets(false)
		
	if data[3] != 0:
		print("MQTT exception ", data[3])
		return cleanupsockets(false)

	in_wait_msg = false
	emit_signal("broker_connected")
	print("broker_connected lw_msg=", PoolByteArray(lw_topic).get_string_from_ascii(), PoolByteArray(lw_msg).get_string_from_ascii())
	return true

func is_connected_to_server():
	if socket != null and socket.is_connected_to_host():
		return true
	if websocket != null and websocket.is_connected_to_host():
		return true
	return false

func disconnect_from_server():
	#senddata(PoolByteArray([0xE0, 0x00]))
	var wasconnected = is_connected_to_server()
	cleanupsockets()
	if wasconnected:
		emit_signal("broker_disconnected")
	
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
			var op = yield(Ywait_msg(), "completed")
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

func Ywait_msg():
	yield(get_tree(), "idle_frame") 
	if receivedbufferlength() <= 0:
		return
		
	var res = yield(Yreceivedbuffernextbyte(), "completed")

	if res == null:
		return null
	if res == 0:
		return false # raise OSError(-1)
	if res == 0xD0:  # PINGRESP
		#print("PINGRESP")
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
	var pid1
	if op & 6:
		pid1 = yield(Yreceivedbuffernext2byteWord(), "completed")
		sz -= 2
	data = yield(YreceivedbuffernextNbytes(sz), "completed")
	var msg = data if binarymessages else data.get_string_from_ascii()
	
	emit_signal("received_message", topic, msg)
	
	if op & 6 == 2:
		senddata(PoolByteArray([0x40, 0x02, (pid1 >> 8), (pid1 & 0xFF)]))
	elif op & 6 == 4:
		assert(0)

func trimreceivedbuffer(n):
	if n == receivedbuffer.size():
		 receivedbuffer = PoolByteArray()
	else:
		assert (n <= receivedbuffer.size())
		receivedbuffer = receivedbuffer.subarray(n, -1)

func wait_msg():
	var n = receivedbuffer.size()
	if n < 2:
		return 0
	var op = receivedbuffer[0]
	var i = 1
	var sz = receivedbuffer[i] & 0x7f
	while (receivedbuffer[i] & 0x80):
		i += 1
		if i == n:
			return 0
		sz += (receivedbuffer[i] & 0x7f) << ((i-1)*7)
	i += 1
	if n < i + sz:
		return 0
		
	var E = 0
	if op == 0xd0:  # PINGRESP
		if n >= 2:
			E = 0 if (sz == 0) else 1
			
	elif op & 0xf0 == 0x30:
		var topic_len = (receivedbuffer[i]<<8) + receivedbuffer[i+1]
		var im = i + 2
		var topic = receivedbuffer.subarray(im, im + topic_len - 1).get_string_from_ascii()
		im += topic_len
		var pid1 = 0
		if op & 6:
			pid1 = (receivedbuffer[im]<<8) + receivedbuffer[im+1]
			im += 2
		var data = receivedbuffer.subarray(im, i + sz - 1)
		var msg = data if binarymessages else data.get_string_from_ascii()
		
		print("received topic=", topic, " msg=", msg)
		emit_signal("received_message", topic, msg)
		
		if op & 6 == 2:
			senddata(PoolByteArray([0x40, 0x02, (pid1 >> 8), (pid1 & 0xFF)]))
		elif op & 6 == 4:
			assert(0)

	elif op == 0x90:
		print("Subscribe acknowledgement ", receivedbuffer.subarray(i, i + sz - 1), self.pid)
	else:
		print("mqtt do something with op=%x" % op)

	trimreceivedbuffer(i + sz)
	return E

