extends HBoxContainer

@onready var NetworkGateway = $"../NetworkGateway"

func _ready():
	$ShowNetworkGateway.set_pressed_no_signal(NetworkGateway.visible)
	
func _on_show_network_gateway_toggled(toggled_on):
	NetworkGateway.visible = toggled_on

func _on_connect_toggled(toggled_on):
	if toggled_on:
		NetworkGateway.get_node("MQTTsignalling/roomname").text = $Roomname.text
		NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_NECESSARY)
		NetworkGateway.set_vox_on()
	else:
		NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF)

func _process(delta):
	$PlayerCount.value = NetworkGateway.Dconnectedplayerscount
