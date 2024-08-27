extends ColorRect

@onready var NetworkGateway = get_node("../..")

func _on_NetworkOptionsMQTTWebRTC_item_selected(ns):
	#assert (ProtocolOptions.selected == NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL)
	var selectasoff = (ns == NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF)
	if not selectasoff:
		NetworkGateway.PlayerConnections.clearconnectionlog()
	$StartMQTT.button_pressed = false
	await get_tree().process_frame
	if $StartMQTT.is_connected("toggled", Callable($Servermode, "_on_StartServer_toggled")):
		$StartMQTT.disconnect("toggled", Callable($Servermode, "_on_StartServer_toggled"))
	if $StartMQTT.is_connected("toggled", Callable($Clientmode, "_on_StartClient_toggled")):
		$StartMQTT.disconnect("toggled", Callable($Clientmode, "_on_StartClient_toggled"))

	var selectasserver = (ns == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_SERVER)
	var selectasclient = (ns == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_CLIENT)
	var selectasnecessary = (ns == NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_NECESSARY)
	$Servermode.visible = selectasserver
	$Clientmode.visible = selectasclient
	NetworkGateway.ProtocolOptions.disabled = not selectasoff
	if selectasserver:
		$StartMQTT.connect("toggled", Callable($Servermode, "_on_StartServer_toggled"))
		if $mqttautoconnect.button_pressed:
			$StartMQTT.button_pressed = true
	if selectasclient or selectasnecessary:
		$StartMQTT.connect("toggled", Callable($Clientmode, "_on_StartClient_toggled"))
		if $mqttautoconnect.button_pressed:
			$StartMQTT.button_pressed = true
#	if $MQTTsignalling/mqttautoconnect.button_pressed:
#		$MQTTsignalling/StartMQTT.button_pressed = selectasclient or selectasnecessary
	$Servermode/WebRTCmultiplayerserver/StartWebRTCmultiplayer.button_pressed = false
	$Servermode/WebRTCmultiplayerserver/StartWebRTCmultiplayer.disabled = true
	$Clientmode/WebRTCmultiplayerclient/StartWebRTCmultiplayer.button_pressed = false
	$Clientmode/WebRTCmultiplayerclient/StartWebRTCmultiplayer.disabled = true
