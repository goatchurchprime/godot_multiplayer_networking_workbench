extends Panel

# keep trying to get the HTML5 version working (not connecting to mqtt!)
# http://goatchurchprime.github.io/godot_multiplayer_networking_workbench/minimal_peer_networking.html


export var remoteservers = [ "192.168.43.1", "192.168.8.111" ]



enum NETWORK_PROTOCOL { ENET = 0, 
						WEBSOCKET = 1,
						WEBRTC_WEBSOCKETSIGNAL = 2
						WEBRTC_MQTTSIGNAL = 3
					  }
enum NETWORK_OPTIONS { NETWORK_OFF = 0
					   AS_SERVER = 1,
					   LOCAL_NETWORK = 2,
					   FIXED_URL = 3,
					 }

const errordecodes = { ERR_ALREADY_IN_USE:"ERR_ALREADY_IN_USE", 
					   ERR_CANT_CREATE:"ERR_CANT_CREATE"
					 }


func _on_ProtocolOptions_item_selected(np):
	assert ($NetworkOptions.selected == 0 and $NetworkOptionsMQTTWebRTC.selected == 0)
	var selectasmqttwebrtc = (np == NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL)
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

	
func _on_OptionButton_item_selected(ns):
	print("_on_OptionButton_item_selected_on_OptionButton_item_selected_on_OptionButton_item_selected ", ns)
	var selectasoff = (ns == NETWORK_OPTIONS.NETWORK_OFF)
	if not selectasoff:
		$PlayerConnections/ConnectionLog.text = ""

	if $PlayerConnections.LocalPlayer.networkID != 0:
		if get_tree().get_network_peer() != null:
			print("closing connection ", $PlayerConnections.LocalPlayer.networkID, get_tree().get_network_peer())
		$PlayerConnections.force_server_disconnect()
	assert ($PlayerConnections.LocalPlayer.networkID == 0)
	if $UDPipdiscovery/Servermode.is_processing():
		$UDPipdiscovery/Servermode.stopUDPbroadcasting()
	if $UDPipdiscovery/Clientmode.is_processing():
		$UDPipdiscovery/Clientmode.stopUDPreceiving()
	$ENetMultiplayer/Servermode/StartENetmultiplayer.pressed = false
	$ENetMultiplayer/Clientmode/StartENetmultiplayer.pressed = false
	$WebSocketMultiplayer/Servermode/StartWebSocketmultiplayer.pressed = false
	$WebSocketMultiplayer/Clientmode/StartWebSocketmultiplayer.pressed = false
	
	var np = $ProtocolOptions.selected 
	assert (np != NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL)

	var selectasserver = (ns == NETWORK_OPTIONS.AS_SERVER)
	var selectasclient = (ns > NETWORK_OPTIONS.LOCAL_NETWORK)
	var selectassearchingclient = (ns == NETWORK_OPTIONS.LOCAL_NETWORK)
	var selectUDPipdiscoveryserver = selectasserver and (not OS.has_feature("Server")) and (not OS.has_feature("HTML5"))
	var selectasenet = (np == NETWORK_PROTOCOL.ENET)
	var selectaswebsocket = (np == NETWORK_PROTOCOL.WEBSOCKET)	

	if selectasoff:
		$UDPipdiscovery.visible = (not OS.has_feature("Server")) and (not OS.has_feature("HTML5"))
	else:
		$UDPipdiscovery.visible = selectUDPipdiscoveryserver or selectassearchingclient
	assert (not $MQTTsignalling.visible)
	$ProtocolOptions.disabled = not selectasoff
	$UDPipdiscovery/Servermode.visible = selectasserver
	if selectUDPipdiscoveryserver and $UDPipdiscovery/udpenabled.pressed:
		$UDPipdiscovery/Servermode.startUDPbroadcasting()
	if selectassearchingclient:
		$UDPipdiscovery/Clientmode.startUDPreceiving()
	
	if selectasenet:
		$ENetMultiplayer/Servermode.visible = selectasserver
		$ENetMultiplayer/Clientmode.visible = selectasclient or selectassearchingclient
		$ENetMultiplayer/Clientmode/StartENetmultiplayer.disabled = selectassearchingclient
		if $ENetMultiplayer/autoconnect.pressed:
			if selectasserver:
				$ENetMultiplayer/Servermode/StartENetmultiplayer.pressed = true
			if selectasclient:
				$ENetMultiplayer/Clientmode/StartENetmultiplayer.pressed = true

	if selectaswebsocket:
		$WebSocketMultiplayer/Servermode.visible = selectasserver
		$WebSocketMultiplayer/Clientmode.visible = selectasclient or selectassearchingclient
		$WebSocketMultiplayer/Clientmode/StartWebSocketmultiplayer.disabled = selectassearchingclient
		if $WebSocketMultiplayer/autoconnect.pressed:
			if selectasserver:
				$WebSocketMultiplayer/Servermode/StartWebSocketmultiplayer.pressed = true
			if selectasclient:
				$WebSocketMultiplayer/Clientmode/StartWebSocketmultiplayer.pressed = true

func _on_udpenabled_toggled(button_pressed):
	$NetworkOptions.set_item_disabled(NETWORK_OPTIONS.LOCAL_NETWORK, not button_pressed)

func _on_NetworkOptionsMQTTWebRTC_item_selected(ns):
	assert ($ProtocolOptions.selected == NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL)
	var selectasoff = (ns == NETWORK_OPTIONS.NETWORK_OFF)
	if not selectasoff:
		$PlayerConnections/ConnectionLog.text = ""
	var selectasserver = (ns == NETWORK_OPTIONS.AS_SERVER)
	var selectasclient = (ns >= NETWORK_OPTIONS.LOCAL_NETWORK)
	$MQTTsignalling/Servermode.visible = selectasserver
	$MQTTsignalling/Clientmode.visible = selectasclient
	$ProtocolOptions.disabled = not selectasoff
	if $MQTTsignalling/mqttautoconnect.pressed or $MQTTsignalling/Servermode/StartServer.pressed:
		$MQTTsignalling/Servermode/StartServer.pressed = selectasserver
	if $MQTTsignalling/mqttautoconnect.pressed or $MQTTsignalling/Clientmode/StartClient.pressed:
		$MQTTsignalling/Clientmode/StartClient.pressed = selectasclient
	$MQTTsignalling/Servermode/WebRTCmultiplayerserver/StartWebRTCmultiplayer.pressed = false
	$MQTTsignalling/Servermode/WebRTCmultiplayerserver/StartWebRTCmultiplayer.disabled = true
	$MQTTsignalling/Clientmode/WebRTCmultiplayerclient/StartWebRTCmultiplayer.pressed = false
	$MQTTsignalling/Clientmode/WebRTCmultiplayerclient/StartWebRTCmultiplayer.disabled = true


func _ready():
	for rs in remoteservers:
		$NetworkOptions.add_item(rs)
	_on_ProtocolOptions_item_selected($ProtocolOptions.selected)
	_on_udpenabled_toggled($UDPipdiscovery/udpenabled.pressed)
	if OS.has_feature("Server"):
		yield(get_tree().create_timer(1.5), "timeout")
		$NetworkOptions.select(NETWORK_OPTIONS.AS_SERVER)
	if OS.has_feature("HTML5"):
		$NetworkOptions.set_item_disabled(NETWORK_OPTIONS.LOCAL_NETWORK,  true)
		$NetworkOptions.set_item_disabled(NETWORK_OPTIONS.AS_SERVER,  true)
		$MQTTsignalling/brokeraddress/usewebsocket.pressed = true
		$MQTTsignalling/brokeraddress/usewebsocket.disabled = true
		$ProtocolOptions.set_item_disabled(NETWORK_PROTOCOL.ENET, true)
		$ProtocolOptions.selected = max(NETWORK_PROTOCOL.WEBSOCKET, $ProtocolOptions.selected)


func _input(event):
	if event is InputEventKey and event.pressed:
		var bsel = -1
		if (event.scancode == KEY_0):	bsel = 0
		elif (event.scancode == KEY_1):	bsel = 1
		elif (event.scancode == KEY_2):	bsel = 2
		elif (event.scancode == KEY_3):	bsel = 3
		elif (event.scancode == KEY_4):	bsel = 4

		if bsel != -1 and $NetworkOptions.selected != bsel:
			$NetworkOptions.select(bsel)
			_on_OptionButton_item_selected(bsel)
		elif (event.scancode == KEY_G):
			$PlayerConnections/Doppelganger.pressed = not $PlayerConnections/Doppelganger.pressed

func setnetworkoff():
	$NetworkOptions.select(NETWORK_OPTIONS.NETWORK_OFF)
	_on_OptionButton_item_selected(NETWORK_OPTIONS.NETWORK_OFF)
					
func _data_channel_received(channel: Object):
	print("_data_channel_received ", channel)








