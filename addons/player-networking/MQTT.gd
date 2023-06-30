extends Node

# MQTT client implementation in GDScript
# Based on https://github.com/pycom/pycom-libraries/blob/master/lib/mqtt/mqtt.py
# and initial work by Alex J Lennon <ajlennon@dynamicdevices.co.uk>

# mosquitto_sub -h test.mosquitto.org -v -t "metest/#"
# mosquitto_pub -h test.mosquitto.org -t "metest/retain" -m "retained message" -r

@export var client_id = ""
	
var socket = null
var sslsocket = null
var websocketclient = null
var websocket = null

const BCM_NOCONNECTION = 0
const BCM_WAITING_WEBSOCKET_CONNECTION = 1
const BCM_WAITING_SOCKET_CONNECTION = 2
const BCM_WAITING_SSL_SOCKET_CONNECTION = 3
const BCM_FAILED_CONNECTION = 5
const BCM_WAITING_CONNMESSAGE = 10
const BCM_WAITING_CONNACK = 19
const BCM_CONNECTED = 20

var brokerconnectmode = BCM_NOCONNECTION

var regexbrokerurl = RegEx.new()

const DEFAULTBROKERPORT_TCP = 1883
const DEFAULTBROKERPORT_SSL = 8884
const DEFAULTBROKERPORT_WS = 8080
const DEFAULTBROKERPORT_WSS = 8081

const CP_PINGREQ = 0xC0
const CP_PINGRESP = 0xd0
const CP_CONNACK = 0x20
const CP_CONNECT = 0x10
const CP_PUBLISH = 0x30
const CP_SUBSCRIBE = 0x82
const CP_SUBACK = 0x90

var binarymessages = false

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

var receivedbuffer : PackedByteArray = PackedByteArray()

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
	
func receiveintobuffer():
	if socket != null and socket.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		var n = socket.get_available_bytes()
		if n != 0:
			var sv = socket.get_data(n)
			assert (sv[0] == 0)  # error code
			receivedbuffer.append_array(sv[1])
			
	elif sslsocket != null:
		if sslsocket.status == StreamPeerTLS.STATUS_CONNECTED or sslsocket.status == StreamPeerTLS.STATUS_HANDSHAKING:
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
	
	
var pingticksnext0 = 0
func _process(delta):
	if brokerconnectmode == BCM_NOCONNECTION:
		pass
	elif brokerconnectmode == BCM_WAITING_WEBSOCKET_CONNECTION:
		websocketclient.poll()
		if websocket.is_connected_to_host():
			brokerconnectmode = BCM_WAITING_CONNMESSAGE
			
	elif brokerconnectmode == BCM_WAITING_SOCKET_CONNECTION:
		socket.poll()
		if socket.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			brokerconnectmode = BCM_WAITING_CONNMESSAGE

	elif brokerconnectmode == BCM_WAITING_SSL_SOCKET_CONNECTION:
		socket.poll()
		if socket.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			if sslsocket == null:
				sslsocket = StreamPeerTLS.new()
				print("calling sslsocket.connect_to_stream()...")
				var E3 = sslsocket.connect_to_stream(socket)
				print("finish calling sslsocket.connect_to_stream()")
				if E3 != 0:
					print("bad sslsocket.connect_to_stream E=", E3)
					brokerconnectmode = BCM_FAILED_CONNECTION
					sslsocket = null
			if sslsocket != null and sslsocket.get_status() == StreamPeerTLS.STATUS_CONNECTED:
				print("CCSS ", sslsocket.get_status())
				if sslsocket.get_status() == StreamPeerTLS.STATUS_CONNECTED:
					brokerconnectmode = BCM_WAITING_CONNMESSAGE
				
	elif brokerconnectmode == BCM_WAITING_CONNMESSAGE:
		senddata(firstmessagetoserver())
		brokerconnectmode = BCM_WAITING_CONNACK
		
	elif brokerconnectmode == BCM_WAITING_CONNACK or brokerconnectmode == BCM_CONNECTED:
		receiveintobuffer()
		wait_msg()
		if brokerconnectmode == BCM_CONNECTED and pingticksnext0 < Time.get_ticks_msec():
			senddata(PackedByteArray([CP_PINGREQ, 0x00]))
			pingticksnext0 = Time.get_ticks_msec() + pinginterval*1000

	elif brokerconnectmode == BCM_FAILED_CONNECTION:
		cleanupsockets()


func _ready():
	regexbrokerurl.compile('^(wss://|ws://|ssl://)?([^:\\s]+)(:\\d+)?(/\\S*)?$')
	if client_id == "":
		randomize()
		client_id = "rr%d" % randi()

func set_last_will(topic, msg, retain=false, qos=0):
	assert((0 <= qos) and (qos <= 2))
	assert(topic)
	self.lw_topic = topic.to_ascii_buffer()
	self.lw_msg = msg if binarymessages else msg.to_ascii_buffer()
	self.lw_qos = qos
	self.lw_retain = retain

func firstmessagetoserver():
	var clean_session = true
	var msg = PackedByteArray()
	msg.append(CP_CONNECT);
	msg.append(0x00);
	msg.append(0x00);
	msg.append(0x04);
	msg.append_array("MQTT".to_ascii_buffer());
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
	msg.append_array(self.client_id.to_ascii_buffer())
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
		msg.append_array(self.user.to_ascii_buffer())
		msg.append(self.pswd.length() >> 8)
		msg.append(self.pswd.length() & 0xFF)
		msg.append_array(self.pswd.to_ascii_buffer())
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
	brokerconnectmode = BCM_NOCONNECTION
	return retval

func connect_to_broker(brokerurl):
	assert (brokerconnectmode == BCM_NOCONNECTION)
	var brokermatch = regexbrokerurl.search(brokerurl)
	if brokermatch == null:
		print("unrecognized brokerurl pattern:", brokerurl)
		return cleanupsockets(false)
	var brokercomponents = brokermatch.strings
	var brokerprotocol = brokercomponents[1]
	var brokerserver = brokercomponents[2]
	var iswebsocket = (brokerprotocol == "ws://" or brokerprotocol == "wss://")
	var isssl = (brokerprotocol == "ssl://" or brokerprotocol == "wss://")
	var brokerport = ((DEFAULTBROKERPORT_WSS if isssl else DEFAULTBROKERPORT_WS) if iswebsocket else (DEFAULTBROKERPORT_SSL if isssl else DEFAULTBROKERPORT_TCP))
	if brokercomponents[3]:
		brokerport = int(brokercomponents[3].substr(1)) 
	var brokerpath = brokercomponents[4] if brokercomponents[4] else "/"
	
	var Dcount = 0
	if iswebsocket:
		websocketclient = WebSocketPeer.new()
		websocketclient.verify_ssl = isssl
		var websocketurl = ("wss://" if isssl else "ws://") + brokerserver + ":" + str(brokerport) + brokerpath
		print("Connecting to websocketurl: ", websocketurl)
		var E = websocketclient.connect_to_url(websocketurl, PackedStringArray(["mqttv3.1"]))
		if E != 0:
			print("websocketclient.connect_to_url Err: ", E)
			return cleanupsockets(false)
		websocket = websocketclient.get_peer(1)
		brokerconnectmode = BCM_WAITING_WEBSOCKET_CONNECTION

	else:
		socket = StreamPeerTCP.new()
		print("Connecting to %s:%s" % [brokerserver, brokerport])
		var E = socket.connect_to_host(brokerserver, brokerport)
		if E != 0:
			print("socketclient.connect_to_url Err: ", E)
			return cleanupsockets(false)
		brokerconnectmode = BCM_WAITING_SSL_SOCKET_CONNECTION if isssl else BCM_WAITING_SOCKET_CONNECTION
		
	return true


func disconnect_from_server():
	if brokerconnectmode == BCM_CONNECTED:
		senddata(PackedByteArray([0xE0, 0x00]))
		emit_signal("broker_disconnected")
	cleanupsockets()
	
func publish(topic, msg, retain=false, qos=0):
	if not binarymessages:
		msg = msg.to_ascii_buffer()
	topic = topic.to_ascii_buffer()
	
	if socket != null:
		if not socket.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			return
	elif websocket != null:
		if not websocket.is_connected_to_host():
			return
	else:
		return

	var pkt = PackedByteArray()
	pkt.append(CP_PUBLISH);
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


func subscribe(topic, qos=0):
	self.pid += 1
	topic = topic.to_ascii_buffer()
	var length = 2 + 2 + len(topic) + 1
	var msg = PackedByteArray()
	msg.append(CP_SUBSCRIBE);
	msg.append(length)
	msg.append(self.pid >> 8)
	msg.append(self.pid & 0xFF)
	msg.append(len(topic) >> 8)
	msg.append(len(topic) & 0xFF)
	msg.append_array(topic)
	msg.append(qos);
	senddata(msg)


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
	if op == CP_PINGRESP:
		if n >= 2:
			E = 0 if (sz == 0) else 1
			
	elif op & 0xf0 == 0x30:
		var topic_len = (receivedbuffer[i]<<8) + receivedbuffer[i+1]
		var im = i + 2
		var topic = receivedbuffer.slice(im, im + topic_len).get_string_from_ascii()
		im += topic_len
		var pid1 = 0
		if op & 6:
			pid1 = (receivedbuffer[im]<<8) + receivedbuffer[im+1]
			im += 2
		var data = receivedbuffer.slice(im, i + sz)
		var msg = data if binarymessages else data.get_string_from_ascii()
		
		print("received topic=", topic, " msg=", msg)
		emit_signal("received_message", topic, msg)
		
		if op & 6 == 2:
			senddata(PackedByteArray([0x40, 0x02, (pid1 >> 8), (pid1 & 0xFF)]))
		elif op & 6 == 4:
			assert(0)

	elif op == CP_SUBACK:
		if sz == 3:
			var apid = (receivedbuffer[i]<<8) + receivedbuffer[i+1]
			print("SUBACK", apid, " ", receivedbuffer[i+2])
			if receivedbuffer[i+2] == 0x80:
				E = 2
		else:
			E = 1

	elif op == CP_CONNACK:
		if sz == 2:
			var retcode = receivedbuffer[i+1]
			print("CONNACK", retcode)
			if retcode == 0x00:
				emit_signal("broker_connected")
			else:
				print("Bad connection retcode=", retcode) # see https://docs.oasis-open.org/mqtt/mqtt/v3.1.1/mqtt-v3.1.1.html
				E = 3
		else:
			E = 1

	else:
		print("mqtt do something with op=%x" % op)

	trimreceivedbuffer(i + sz)
	return E

func trimreceivedbuffer(n):
	if n == receivedbuffer.size():
		receivedbuffer = PackedByteArray()
	else:
		assert (n <= receivedbuffer.size())
		receivedbuffer = receivedbuffer.slice(n)
