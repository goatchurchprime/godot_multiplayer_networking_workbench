extends Control

@onready var NetworkGateway = find_parent("NetworkGateway")

func _on_NetworkOptionsMQTTWebRTC_item_selected(ns):
	#assert (ProtocolOptions.selected == NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL)
	var selectasoff = (ns == NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF)
	if not selectasoff:
		NetworkGateway.PlayerConnections.clearconnectionlog()
	$VBox/HBox2/StartMQTT.button_pressed = false
	await get_tree().process_frame
	if $VBox/HBox2/StartMQTT.is_connected("toggled", Callable($VBox/Servermode, "_on_StartServer_toggled")):
		$VBox/HBox2/StartMQTT.disconnect("toggled", Callable($VBox/Servermode, "_on_StartServer_toggled"))
	if $VBox/HBox2/StartMQTT.is_connected("toggled", Callable($VBox/Clientmode, "_on_StartClient_toggled")):
		$VBox/HBox2/StartMQTT.disconnect("toggled", Callable($VBox/Clientmode, "_on_StartClient_toggled"))

	var selectasserver = (ns == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_SERVER)
	var selectasclient = (ns == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_CLIENT)
	var selectasnecessary = (ns == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_NECESSARY or ns == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_NECESSARY_MANUALCHANGE)
	$VBox/Servermode.visible = selectasserver
	$VBox/Clientmode.visible = selectasclient
	NetworkGateway.ProtocolOptions.disabled = not selectasoff
	if selectasserver:
		$VBox/HBox2/StartMQTT.connect("toggled", Callable($VBox/Servermode, "_on_StartServer_toggled"))
		if $VBox/HBox2/mqttautoconnect.button_pressed:
			$VBox/HBox2/StartMQTT.button_pressed = true
	if selectasclient or selectasnecessary:
		$VBox/HBox2/StartMQTT.connect("toggled", Callable($VBox/Clientmode, "_on_StartClient_toggled"))
		if $VBox/HBox2/mqttautoconnect.button_pressed:
			$VBox/HBox2/StartMQTT.button_pressed = true
#	if $MQTTsignalling/mqttautoconnect.button_pressed:
#		$MQTTsignalling/StartMQTT.button_pressed = selectasclient or selectasnecessary
	$VBox/Servermode/WebRTCmultiplayerserver/StartWebRTCmultiplayer.button_pressed = false
	$VBox/Servermode/WebRTCmultiplayerserver/StartWebRTCmultiplayer.disabled = true
	$VBox/Clientmode/WebRTCmultiplayerclient/StartWebRTCmultiplayer.button_pressed = false
	$VBox/Clientmode/WebRTCmultiplayerclient/StartWebRTCmultiplayer.disabled = true
