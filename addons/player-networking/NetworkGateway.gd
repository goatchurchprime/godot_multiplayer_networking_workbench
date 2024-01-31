extends Panel

# keep trying to get the HTML5 version working (not connecting to mqtt!)
# http://goatchurchprime.github.io/godot_multiplayer_networking_workbench/minimal_peer_networking.html

# make sure you download the webrtc libraries from here: https://github.com/godotengine/webrtc-native/releases

# check UDP works on phone or network
# make a new timeline visualizer that shows the jitter of the recent incoming packets

@export var remoteservers = [ "127.0.0.1" ]
@export var playersnodepath : NodePath = "/root/Main/Players"
@export var localplayerscene : String = "" # "res://controlplayer.tscn"

enum NETWORK_PROTOCOL { ENET = 0, 
						WEBSOCKET = 1,
						WEBRTC_WEBSOCKETSIGNAL = 2,
						WEBRTC_MQTTSIGNAL = 3
					}
enum NETWORK_OPTIONS { NETWORK_OFF = 0,
						AS_SERVER = 1,
						LOCAL_NETWORK = 2,
						FIXED_URL = 3
					}

enum NETWORK_OPTIONS_MQTT_WEBRTC { 
						NETWORK_OFF = 0,
						AS_SERVER = 1,
						AS_CLIENT = 2,
						AS_NECESSARY = 3
					}


const errordecodes = { ERR_ALREADY_IN_USE:"ERR_ALREADY_IN_USE", 
					   ERR_CANT_CREATE:"ERR_CANT_CREATE"
					 }
var rng = RandomNumberGenerator.new()

	
func _ready():
	for rs in remoteservers:
		$NetworkOptions.add_item(rs)
	if OS.has_feature("HTML5"):
		$NetworkOptions.set_item_disabled(NETWORK_OPTIONS.LOCAL_NETWORK,  true)
		$NetworkOptions.set_item_disabled(NETWORK_OPTIONS.AS_SERVER,  true)
		$ProtocolOptions.set_item_disabled(NETWORK_PROTOCOL.ENET, true)
		$ProtocolOptions.selected = max(NETWORK_PROTOCOL.WEBSOCKET, $ProtocolOptions.selected)
	rng.randomize()
	_on_ProtocolOptions_item_selected($ProtocolOptions.selected)

func initialstatenormal(protocol, networkoption):
	assert (protocol >= NETWORK_PROTOCOL.ENET and protocol <= NETWORK_PROTOCOL.WEBRTC_WEBSOCKETSIGNAL)
	$ProtocolOptions.selected = protocol
	_on_ProtocolOptions_item_selected($ProtocolOptions.selected)
	selectandtrigger_networkoption(networkoption)

func initialstatemqttwebrtc(networkoption, roomname, brokeraddress):
	$ProtocolOptions.selected = NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL
	_on_ProtocolOptions_item_selected($ProtocolOptions.selected)
	if brokeraddress:
		$MQTTsignalling/brokeraddress.text = brokeraddress
	if roomname:
		$MQTTsignalling/roomname.text = roomname
	$NetworkOptionsMQTTWebRTC.selected = networkoption
	_on_NetworkOptionsMQTTWebRTC_item_selected($NetworkOptionsMQTTWebRTC.selected)

func selectandtrigger_networkoption(networkoption):
	if $ProtocolOptions.selected == NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL:
		if $NetworkOptionsMQTTWebRTC.selected != networkoption:
			$NetworkOptionsMQTTWebRTC.selected = networkoption
			_on_NetworkOptionsMQTTWebRTC_item_selected(networkoption)
	else:
		if $NetworkOptions.selected != networkoption:
			$NetworkOptions.selected = networkoption
			_on_NetworkOptions_item_selected(networkoption)

func _on_ProtocolOptions_item_selected(np):
	assert ($NetworkOptions.selected == NETWORK_OPTIONS.NETWORK_OFF and $NetworkOptionsMQTTWebRTC.selected == NETWORK_OPTIONS_MQTT_WEBRTC.NETWORK_OFF)
	var selectasmqttwebrtc = (np == NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL)
	var selectaswebrtcwebsocket = (np == NETWORK_PROTOCOL.WEBRTC_WEBSOCKETSIGNAL)
	var selectasenet = (np == NETWORK_PROTOCOL.ENET)
	var selectaswebsocket = (np == NETWORK_PROTOCOL.WEBSOCKET)	
	$NetworkOptions.visible = not selectasmqttwebrtc
	$NetworkOptionsMQTTWebRTC.visible = selectasmqttwebrtc
	$MQTTsignalling.visible = selectasmqttwebrtc
	$MQTTsignalling/Servermode.visible = false
	$MQTTsignalling/Clientmode.visible = false
	$UDPipdiscovery.visible = $NetworkOptions.visible and (not OS.has_feature("Server")) and (not OS.has_feature("HTML5"))
	$ENetMultiplayer.visible = selectasenet
	$ENetMultiplayer/Servermode.visible = false
	$ENetMultiplayer/Clientmode.visible = false
	$WebSocketMultiplayer.visible = selectaswebsocket
	$WebSocketMultiplayer/Servermode.visible = false
	$WebSocketMultiplayer/Clientmode.visible = false
	$WebSocketsignalling.visible = selectaswebrtcwebsocket
	$WebSocketsignalling/Servermode.visible = false
	$WebSocketsignalling/Clientmode.visible = false

	
func _on_NetworkOptions_item_selected(ns):
	print("_on_OptionButton_item_selected_on_OptionButton_item_selected_on_OptionButton_item_selected ", ns)
	var selectasoff = (ns == NETWORK_OPTIONS.NETWORK_OFF)
	if not selectasoff:
		$PlayerConnections.clearconnectionlog()

	if $PlayerConnections.LocalPlayer.get_node("PlayerFrame").networkID != 0:
		if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
			print("closing connection ", $PlayerConnections.LocalPlayer.get_node("PlayerFrame").networkID, multiplayer.multiplayer_peer)
		$PlayerConnections._server_disconnected()
	assert ($PlayerConnections.LocalPlayer.get_node("PlayerFrame").networkID == 0)
	if $UDPipdiscovery/Servermode.is_processing():
		$UDPipdiscovery/Servermode.stopUDPbroadcasting()
	if $UDPipdiscovery/Clientmode.is_processing():
		$UDPipdiscovery/Clientmode.stopUDPreceiving()
	$ENetMultiplayer/Servermode/StartENetmultiplayer.button_pressed = false
	$ENetMultiplayer/Clientmode/StartENetmultiplayer.button_pressed = false
	$WebSocketMultiplayer/Servermode/StartWebSocketmultiplayer.button_pressed = false
	$WebSocketMultiplayer/Clientmode/StartWebSocketmultiplayer.button_pressed = false
	if $WebSocketsignalling/Servermode.websocketserver != null:
		$WebSocketsignalling/Servermode.stopwebsocketsignalserver()
	if $WebSocketsignalling/Clientmode.websocketclient != null:
		$WebSocketsignalling/Clientmode.stopwebsocketsignalclient()

	var np = $ProtocolOptions.selected 
	assert (np != NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL)

	var selectasserver = (ns == NETWORK_OPTIONS.AS_SERVER)
	var selectasclient = (ns > NETWORK_OPTIONS.LOCAL_NETWORK)
	var selectassearchingclient = (ns == NETWORK_OPTIONS.LOCAL_NETWORK)
	var selectUDPipdiscoveryserver = selectasserver and (not OS.has_feature("Server")) and (not OS.has_feature("HTML5"))
	var selectasenet = (np == NETWORK_PROTOCOL.ENET)
	var selectaswebsocket = (np == NETWORK_PROTOCOL.WEBSOCKET)	
	var selectaswebrtcwebsocket = (np == NETWORK_PROTOCOL.WEBRTC_WEBSOCKETSIGNAL)	

	if selectasoff:
		$UDPipdiscovery.visible = (not OS.has_feature("Server")) and (not OS.has_feature("HTML5"))
	else:
		$UDPipdiscovery.visible = selectUDPipdiscoveryserver or selectassearchingclient
	assert (not $MQTTsignalling.visible)
	$ProtocolOptions.disabled = not selectasoff
	$UDPipdiscovery/Servermode.visible = selectasserver
	if selectUDPipdiscoveryserver and $UDPipdiscovery/udpenabled.button_pressed:
		$UDPipdiscovery/Servermode.startUDPbroadcasting()
	if selectassearchingclient:
		$UDPipdiscovery/Clientmode.startUDPreceiving()
	
	if selectasenet:
		$ENetMultiplayer/Servermode.visible = selectasserver
		$ENetMultiplayer/Clientmode.visible = selectasclient or selectassearchingclient
		$ENetMultiplayer/Clientmode/StartENetmultiplayer.disabled = selectassearchingclient
		if $ENetMultiplayer/autoconnect.button_pressed:
			if selectasserver:
				$ENetMultiplayer/Servermode/StartENetmultiplayer.button_pressed = true
			if selectasclient:
				$ENetMultiplayer/Clientmode/StartENetmultiplayer.button_pressed = true

	if selectaswebsocket:
		$WebSocketMultiplayer/Servermode.visible = selectasserver
		$WebSocketMultiplayer/Clientmode.visible = selectasclient or selectassearchingclient
		$WebSocketMultiplayer/Clientmode/StartWebSocketmultiplayer.disabled = selectassearchingclient
		if $WebSocketMultiplayer/autoconnect.button_pressed:
			if selectasserver:
				$WebSocketMultiplayer/Servermode/StartWebSocketmultiplayer.button_pressed = true
			if selectasclient:
				$WebSocketMultiplayer/Clientmode/StartWebSocketmultiplayer.button_pressed = true

	if selectaswebrtcwebsocket:
		$WebSocketsignalling/Servermode.visible = selectasserver
		$WebSocketsignalling/Clientmode.visible = selectasclient or selectassearchingclient
		$WebSocketsignalling/Servermode/WebRTCmultiplayerserver/StartWebRTCmultiplayer.button_pressed = false
		$WebSocketsignalling/Servermode/WebRTCmultiplayerserver/StartWebRTCmultiplayer.disabled = true
		$WebSocketsignalling/Clientmode/WebRTCmultiplayerclient/StartWebRTCmultiplayer.button_pressed = false
		$WebSocketsignalling/Clientmode/WebRTCmultiplayerclient/StartWebRTCmultiplayer.disabled = true
		if selectasserver:
			$WebSocketsignalling/Servermode.startwebsocketsignalserver()
		if selectasclient:
			$WebSocketsignalling/Clientmode.startwebsocketsignalclient()


func _on_udpenabled_toggled(button_pressed):
	$NetworkOptions.set_item_disabled(NETWORK_OPTIONS.LOCAL_NETWORK, not button_pressed)

func _on_NetworkOptionsMQTTWebRTC_item_selected(ns):
	assert ($ProtocolOptions.selected == NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL)
	var selectasoff = (ns == NETWORK_OPTIONS.NETWORK_OFF)
	if not selectasoff:
		$PlayerConnections.clearconnectionlog()
	$MQTTsignalling/StartMQTT.button_pressed = false
	await get_tree().process_frame
	if $MQTTsignalling/StartMQTT.is_connected("toggled", Callable($MQTTsignalling/Servermode, "_on_StartServer_toggled")):
		$MQTTsignalling/StartMQTT.disconnect("toggled", Callable($MQTTsignalling/Servermode, "_on_StartServer_toggled"))
	if $MQTTsignalling/StartMQTT.is_connected("toggled", Callable($MQTTsignalling/Clientmode, "_on_StartClient_toggled")):
		$MQTTsignalling/StartMQTT.disconnect("toggled", Callable($MQTTsignalling/Clientmode, "_on_StartClient_toggled"))

	var selectasserver = (ns == NETWORK_OPTIONS_MQTT_WEBRTC.AS_SERVER)
	var selectasclient = (ns == NETWORK_OPTIONS_MQTT_WEBRTC.AS_CLIENT)
	var selectasnecessary = (ns == NETWORK_OPTIONS_MQTT_WEBRTC.AS_NECESSARY)
	$MQTTsignalling/Servermode.visible = selectasserver
	$MQTTsignalling/Clientmode.visible = selectasclient
	$ProtocolOptions.disabled = not selectasoff
	if selectasserver:
		$MQTTsignalling/StartMQTT.connect("toggled", Callable($MQTTsignalling/Servermode, "_on_StartServer_toggled"))
		if $MQTTsignalling/mqttautoconnect.button_pressed:
			$MQTTsignalling/StartMQTT.button_pressed = true
	if selectasclient or selectasnecessary:
		$MQTTsignalling/StartMQTT.connect("toggled", Callable($MQTTsignalling/Clientmode, "_on_StartClient_toggled"))
		if $MQTTsignalling/mqttautoconnect.button_pressed:
			$MQTTsignalling/StartMQTT.button_pressed = true
#	if $MQTTsignalling/mqttautoconnect.button_pressed:
#		$MQTTsignalling/StartMQTT.button_pressed = selectasclient or selectasnecessary
	$MQTTsignalling/Servermode/WebRTCmultiplayerserver/StartWebRTCmultiplayer.button_pressed = false
	$MQTTsignalling/Servermode/WebRTCmultiplayerserver/StartWebRTCmultiplayer.disabled = true
	$MQTTsignalling/Clientmode/WebRTCmultiplayerclient/StartWebRTCmultiplayer.button_pressed = false
	$MQTTsignalling/Clientmode/WebRTCmultiplayerclient/StartWebRTCmultiplayer.disabled = true



func getrandomdoppelgangerdelay(disabledropout=false):
	if not disabledropout and rng.randf_range(0, 100) < float($DoppelgangerPanel/hbox/VBox_netdrop/netdroppc.text):
		return -1.0
	var netdelayadd = float($DoppelgangerPanel/hbox/VBox_netdelay/netdelayadd.text)
	var doppelgangerdelay = int($DoppelgangerPanel/hbox/VBox_delaymin/netdelaymin.text) + max(0.0, rng.randfn(netdelayadd, netdelayadd*0.4))
	return doppelgangerdelay
	
func setnetworkoff():	
	selectandtrigger_networkoption(NETWORK_OPTIONS.NETWORK_OFF)
					
func _data_channel_received(channel: Object):
	print("_data_channel_received ", channel)











# The button press signal isn't getting through from mouse click
# Although mouse down is sent to the Viewport, a mouse move is received
# works okay in VR though

func _on_mqttautoconnect_pressed():
	pass # print("---- _on_mqttautoconnect_pressedx")


func _on_mqttautoconnect_mouse_entered():
	pass # print("---- _on_mqttautoconnect_mouse_eneeeetered")


func _on_mqttautoconnect_gui_input(event):
	pass #print("input evengt ", event)
