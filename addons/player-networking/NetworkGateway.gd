extends MarginContainer

# keep trying to get the HTML5 version working (not connecting to mqtt!)
# http://goatchurchprime.github.io/godot_multiplayer_networking_workbench/minimal_peer_networking.html

# make sure you download the webrtc libraries from here: https://github.com/godotengine/webrtc-native/releases

# check UDP works on phone or network
# make a new timeline visualizer that shows the jitter of the recent incoming packets

@export var remoteservers = [ "127.0.0.1" ]
@export var playersnodepath : NodePath = "VBox/FallbackPlayersNode"
@export var localplayerscene : String = "res://addons/player-networking/FallbackControlplayer.tscn"
@export var enabled = true

var Dconnectedplayerscount = 0

@onready var ProtocolModes = find_child("ProtocolModes")
@onready var ProtocolOptions = ProtocolModes.find_child("ProtocolOptions")
@onready var NetworkOptions = ProtocolModes.find_child("NetworkOptions")
@onready var NetworkOptions_portnumber = ProtocolModes.find_child("portnumber")
@onready var NetworkOptionsMQTTWebRTC = find_child("NetworkOptionsMQTTWebRTC")
@onready var UDPipdiscovery = find_child("UDPipdiscovery")

@onready var ENetMultiplayer = find_child("ENetMultiplayer")
@onready var WebSocketMultiplayer = find_child("WebSocketMultiplayer")
@onready var WebSocketsignalling = find_child("WebSocketsignalling")
@onready var MQTTsignalling = find_child("MQTTsignalling")

@onready var PlayerConnections = find_child("PlayerConnections")
@onready var DoppelgangerPanel = find_child("DoppelgangerPanel")

signal webrtc_multiplayerpeer_set(asserver)
signal xclientstatusesupdate

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
						AS_NECESSARY = 3,
						AS_NECESSARY_MANUALCHANGE = 4
					}


const errordecodes = { ERR_ALREADY_IN_USE:"ERR_ALREADY_IN_USE", 
					   ERR_CANT_CREATE:"ERR_CANT_CREATE"
					 }
var rng = RandomNumberGenerator.new()
	
func _ready():
	for rs in remoteservers:
		NetworkOptions.add_item(rs)
	if NetworkOptions.selected == -1:  NetworkOptions.selected = 0
	if ProtocolOptions.selected == -1:  ProtocolOptions.selected = 3
	if NetworkOptionsMQTTWebRTC.selected == -1:  NetworkOptionsMQTTWebRTC.selected = 0
	if MQTTsignalling.get_node("VBox/HBox/brokeraddress").selected == -1:  MQTTsignalling.get_node("VBox/HBox/brokeraddress").selected = 0
	if OS.has_feature("HTML5"):
		NetworkOptions.set_item_disabled(NETWORK_OPTIONS.LOCAL_NETWORK,  true)
		NetworkOptions.set_item_disabled(NETWORK_OPTIONS.AS_SERVER,  true)
		ProtocolOptions.set_item_disabled(NETWORK_PROTOCOL.ENET, true)
		ProtocolOptions.selected = max(NETWORK_PROTOCOL.WEBSOCKET, ProtocolOptions.selected)
	rng.randomize()
	_on_ProtocolOptions_item_selected(ProtocolOptions.selected)


func initialstatenormal(protocol, networkoption):
	assert (protocol >= NETWORK_PROTOCOL.ENET and protocol <= NETWORK_PROTOCOL.WEBRTC_WEBSOCKETSIGNAL)
	ProtocolOptions.selected = protocol
	_on_ProtocolOptions_item_selected(ProtocolOptions.selected)
	selectandtrigger_networkoption(networkoption)

func initialstatemqttwebrtc(networkoption, roomname, brokeraddress):
	ProtocolOptions.selected = NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL
	_on_ProtocolOptions_item_selected(ProtocolOptions.selected)
	if brokeraddress:
		MQTTsignalling.get_node("VBox/HBox/brokeraddress").text = brokeraddress
	if roomname:
		MQTTsignalling.Roomnametext.text = roomname
	NetworkOptionsMQTTWebRTC.selected = networkoption
	_on_NetworkOptionsMQTTWebRTC_item_selected(NetworkOptionsMQTTWebRTC.selected)

func selectandtrigger_networkoption(networkoption):
	if ProtocolOptions.selected == NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL:
		if NetworkOptionsMQTTWebRTC.selected != networkoption:
			NetworkOptionsMQTTWebRTC.selected = networkoption
			_on_NetworkOptionsMQTTWebRTC_item_selected(networkoption)
	else:
		if NetworkOptions.selected != networkoption:
			NetworkOptions.selected = networkoption
			_on_NetworkOptions_item_selected(networkoption)

func _on_ProtocolOptions_item_selected(np):
	assert (NetworkOptions.selected == NETWORK_OPTIONS.NETWORK_OFF or NetworkOptions.selected == -1)
	assert (NetworkOptionsMQTTWebRTC.selected == NETWORK_OPTIONS_MQTT_WEBRTC.NETWORK_OFF or NetworkOptionsMQTTWebRTC.selected == -1)
	var selectasmqttwebrtc = (np == NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL)
	var selectaswebrtcwebsocket = (np == NETWORK_PROTOCOL.WEBRTC_WEBSOCKETSIGNAL)
	var selectasenet = (np == NETWORK_PROTOCOL.ENET)
	var selectaswebsocket = (np == NETWORK_PROTOCOL.WEBSOCKET)	
	ProtocolModes.get_node("TabContainer").current_tab = (1 if selectasmqttwebrtc else 0)
	NetworkOptionsMQTTWebRTC.visible = selectasmqttwebrtc
	MQTTsignalling.visible = selectasmqttwebrtc
	UDPipdiscovery.visible = NetworkOptions.visible and (not OS.has_feature("Server")) and (not OS.has_feature("HTML5"))

	ENetMultiplayer.visible = selectasenet
	ENetMultiplayer.get_node("HBox/Servermode").visible = false
	ENetMultiplayer.get_node("HBox/Clientmode").visible = false

	WebSocketMultiplayer.visible = selectaswebsocket
	WebSocketMultiplayer.get_node("HBox/Servermode").visible = false
	WebSocketMultiplayer.get_node("HBox/Clientmode").visible = false
	WebSocketsignalling.visible = selectaswebrtcwebsocket
	WebSocketsignalling.get_node("VBox/Servermode").visible = false
	WebSocketsignalling.get_node("VBox/Clientmode").visible = false

	
func _on_NetworkOptions_item_selected(ns):
	print("_on_OptionButton_item_selected_on_OptionButton_item_selected_on_OptionButton_item_selected ", ns)
	PlayerConnections.connect_multiplayersignals()
	var selectasoff = (ns == NETWORK_OPTIONS.NETWORK_OFF)
	if not selectasoff:
		PlayerConnections.clearconnectionlog()

	if PlayerConnections.LocalPlayer.get_node("PlayerFrame").networkID != 0:
		if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
			print("closing connection ", PlayerConnections.LocalPlayer.get_node("PlayerFrame").networkID, multiplayer.multiplayer_peer)
		PlayerConnections._server_disconnected()
	assert (PlayerConnections.LocalPlayer.get_node("PlayerFrame").networkID == 0)

	if UDPipdiscovery.get_node("Servermode").is_processing():
		UDPipdiscovery.get_node("Servermode").stopUDPbroadcasting()
	if UDPipdiscovery.get_node("Clientmode").is_processing():
		UDPipdiscovery.get_node("Clientmode").stopUDPreceiving()

	ENetMultiplayer.get_node("HBox/Servermode/StartENetmultiplayer").button_pressed = false
	ENetMultiplayer.get_node("HBox/Clientmode/StartENetmultiplayer").button_pressed = false
	WebSocketMultiplayer.get_node("HBox/Servermode/StartWebSocketmultiplayer").button_pressed = false
	WebSocketMultiplayer.get_node("HBox/Clientmode/StartWebSocketmultiplayer").button_pressed = false
	if WebSocketsignalling.get_node("VBox/Servermode").websocketserver != null:
		WebSocketsignalling.get_node("VBox/Servermode").stopwebsocketsignalserver()
	if WebSocketsignalling.get_node("VBox/Clientmode").websocketclient != null:
		WebSocketsignalling.get_node("VBox/Clientmode").stopwebsocketsignalclient()

	var np = ProtocolOptions.selected 
	assert (np != NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL)

	var selectasserver = (ns == NETWORK_OPTIONS.AS_SERVER)
	var selectasclient = (ns > NETWORK_OPTIONS.LOCAL_NETWORK)
	var selectassearchingclient = (ns == NETWORK_OPTIONS.LOCAL_NETWORK)
	var selectUDPipdiscoveryserver = selectasserver and (not OS.has_feature("Server")) and (not OS.has_feature("HTML5"))
	var selectasenet = (np == NETWORK_PROTOCOL.ENET)
	var selectaswebsocket = (np == NETWORK_PROTOCOL.WEBSOCKET)	
	var selectaswebrtcwebsocket = (np == NETWORK_PROTOCOL.WEBRTC_WEBSOCKETSIGNAL)	

	if selectasoff:
		UDPipdiscovery.visible = (not OS.has_feature("Server")) and (not OS.has_feature("HTML5"))
	else:
		UDPipdiscovery.visible = selectUDPipdiscoveryserver or selectassearchingclient
	assert (not MQTTsignalling.visible)
	ProtocolOptions.disabled = not selectasoff
	UDPipdiscovery.get_node("Servermode").visible = selectasserver
	if selectUDPipdiscoveryserver and UDPipdiscovery.get_node("udpenabled").button_pressed:
		UDPipdiscovery.get_node("Servermode").startUDPbroadcasting()
	if selectassearchingclient:
		UDPipdiscovery.get_node("Clientmode").startUDPreceiving()
	
	if selectasenet:
		ENetMultiplayer.get_node("HBox/Servermode").visible = selectasserver
		ENetMultiplayer.get_node("HBox/Clientmode").visible = selectasclient or selectassearchingclient
		ENetMultiplayer.get_node("HBox/Clientmode/StartENetmultiplayer").disabled = selectassearchingclient
		if ENetMultiplayer.get_node("HBox/autoconnect").button_pressed:
			if selectasserver:
				ENetMultiplayer.get_node("HBox/Servermode/StartENetmultiplayer").button_pressed = true
			if selectasclient:
				ENetMultiplayer.get_node("HBox/Clientmode/StartENetmultiplayer").button_pressed = true

	if selectaswebsocket:
		WebSocketMultiplayer.get_node("HBox/Servermode").visible = selectasserver
		WebSocketMultiplayer.get_node("HBox/Clientmode").visible = selectasclient or selectassearchingclient
		WebSocketMultiplayer.get_node("HBox/Clientmode/StartWebSocketmultiplayer").disabled = selectassearchingclient
		if WebSocketMultiplayer.get_node("HBox/autoconnect").button_pressed:
			if selectasserver:
				WebSocketMultiplayer.get_node("HBox/Servermode/StartWebSocketmultiplayer").button_pressed = true
			if selectasclient:
				WebSocketMultiplayer.get_node("HBox/Clientmode/StartWebSocketmultiplayer").button_pressed = true

	if selectaswebrtcwebsocket:
		WebSocketsignalling.get_node("VBox/Servermode").visible = selectasserver
		WebSocketsignalling.get_node("VBox/Clientmode").visible = selectasclient or selectassearchingclient
		WebSocketsignalling.get_node("VBox/Servermode/WebRTCmultiplayerserver/StartWebRTCmultiplayer").button_pressed = false
		WebSocketsignalling.get_node("VBox/Servermode/WebRTCmultiplayerserver/StartWebRTCmultiplayer").disabled = true
		WebSocketsignalling.get_node("VBox/Clientmode/WebRTCmultiplayerclient/StartWebRTCmultiplayer").button_pressed = false
		WebSocketsignalling.get_node("VBox/Clientmode/WebRTCmultiplayerclient/StartWebRTCmultiplayer").disabled = true
		if selectasserver:
			WebSocketsignalling.get_node("VBox/Servermode").startwebsocketsignalserver()
		if selectasclient:
			WebSocketsignalling.get_node("VBox/Clientmode").startwebsocketsignalclient()


func _on_udpenabled_toggled(button_pressed):
	NetworkOptions.set_item_disabled(NETWORK_OPTIONS.LOCAL_NETWORK, not button_pressed)

func _on_NetworkOptionsMQTTWebRTC_item_selected(ns):
	PlayerConnections.connect_multiplayersignals()
	MQTTsignalling._on_NetworkOptionsMQTTWebRTC_item_selected(ns)


func getrandomdoppelgangerdelay(disabledropout=false):
	if not disabledropout and rng.randf_range(0, 100) < float(DoppelgangerPanel.get_node("hbox/VBox_netdrop/netdroppc").text):
		print("Dropped")
		return -1.0
	var netdelayadd = float(DoppelgangerPanel.get_node("hbox/VBox_netdelay/netdelayadd").text)
	var doppelgangerdelay = int(DoppelgangerPanel.get_node("hbox/VBox_delaymin/netdelaymin").text) + max(0.0, rng.randfn(netdelayadd, netdelayadd*0.4))
	return doppelgangerdelay
	
func setnetworkoff():	
	selectandtrigger_networkoption(NETWORK_OPTIONS.NETWORK_OFF)
					
func _data_channel_received(channel: Object):
	print("_data_channel_received ", channel)

func set_vox_on():
	var RecordingFeature = PlayerConnections.get_node("VBox/RecordingFeature")
	RecordingFeature.get_node("Vox").button_pressed = true
	var voxthreshold = 0.06
	RecordingFeature.voxthreshhold = voxthreshold
	RecordingFeature.get_node("VoxThreshold").material.set_shader_parameter("voxthreshhold", voxthreshold)

func is_disconnected():
	return Dconnectedplayerscount == 0

func simple_webrtc_connect(roomname):
	if roomname:
		MQTTsignalling.Roomnametext.text = roomname
		selectandtrigger_networkoption(NETWORK_OPTIONS_MQTT_WEBRTC.AS_NECESSARY)
		set_vox_on()
	else:
		selectandtrigger_networkoption(NETWORK_OPTIONS.NETWORK_OFF)





func _on_brokeraddress_button_down():
	pass # Replace with function body.

func _on_gui_input(event):
	if event is InputEventMouseButton:
		print("_on_gui_input ", event)
	
