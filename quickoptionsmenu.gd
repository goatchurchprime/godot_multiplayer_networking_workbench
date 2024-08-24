extends HBoxContainer

@onready var NetworkGateway = $"../NetworkGateway"

func _ready():
	$ShowNetworkGateway.set_pressed_no_signal(NetworkGateway.visible)
	if OS.has_feature("Server"):
		await get_tree().create_timer(1.5).timeout
		NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS.AS_SERVER)
	
func _on_show_network_gateway_toggled(toggled_on):
	NetworkGateway.visible = toggled_on

func _on_connect_toggled(toggled_on):
	if toggled_on:
		NetworkGateway.get_node("MQTTsignalling/roomname").text = $Roomname.text
		NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_NECESSARY)
		NetworkGateway.set_vox_on()
	else:
		NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF)

func _on_cs_button_toggled(toggled_on):
	if toggled_on:
		NetworkGateway.get_node("ProtocolOptions").selected = NetworkGateway.NETWORK_PROTOCOL.ENET
		NetworkGateway._on_ProtocolOptions_item_selected(NetworkGateway.NETWORK_PROTOCOL.ENET)
		NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS.AS_SERVER)
		NetworkGateway.get_node("UDPipdiscovery/udpenabled").button_pressed = false
		NetworkGateway.set_vox_on()
	else:
		NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF)

func _on_cc_button_toggled(toggled_on):
	if toggled_on:
		NetworkGateway.get_node("ProtocolOptions").selected = NetworkGateway.NETWORK_PROTOCOL.ENET
		NetworkGateway._on_ProtocolOptions_item_selected(NetworkGateway.NETWORK_PROTOCOL.ENET)
		NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS.FIXED_URL)
		NetworkGateway.get_node("UDPipdiscovery/udpenabled").button_pressed = false
		#NetworkGateway.set_vox_on()
	else:
		NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF)

func _process(delta):
	$PlayerCount.value = NetworkGateway.Dconnectedplayerscount
