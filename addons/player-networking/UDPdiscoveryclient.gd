extends Control

var udpdiscoveryport = 4546
const broadcastudpipnum = "255.255.255.255"
const broadcastservermsg = "GodotServer_here!"
var udpdiscoveryreceivingserver = null

func _ready():
	set_process(false)

func startUDPreceiving():
	udpdiscoveryport = int(get_node("../broadcastport").text)
	get_node("../broadcastport").editable = false
	get_node("../udpenabled").disabled = true
	udpdiscoveryreceivingserver = UDPServer.new()
	udpdiscoveryreceivingserver.listen(udpdiscoveryport)
	set_process(true)

func stopUDPreceiving():
	get_node("../broadcastport").editable = true
	get_node("../udpenabled").disabled = false
	udpdiscoveryreceivingserver.stop()
	udpdiscoveryreceivingserver = null
	set_process(false)
	
func _process(delta):
	udpdiscoveryreceivingserver.poll()
	if udpdiscoveryreceivingserver.is_connection_available():
		var peer = udpdiscoveryreceivingserver.take_connection()
		var pkt = peer.get_packet()
		var spkt = pkt.get_string_from_utf8().split(" ")
		print("Received: ", spkt, " from ", peer.get_packet_ip())
		if spkt[0] == broadcastservermsg:
			var NetworkGateway = get_node("../..")
			var NetworkOptions = NetworkGateway.get_node("NetworkOptions")
			var receivedIPnumber = peer.get_packet_ip()
			var ns = NetworkOptions.selected
			for nsi in range(NetworkGateway.NETWORK_OPTIONS.FIXED_URL, NetworkOptions.get_item_count()):
				if receivedIPnumber == NetworkOptions.get_item_text(nsi):
					ns = nsi
					break
			if ns == NetworkGateway.NETWORK_OPTIONS.LOCAL_NETWORK:
				NetworkOptions.add_item(receivedIPnumber)
				ns = NetworkOptions.get_item_count() - 1
			NetworkOptions.select(ns)
			NetworkGateway._on_OptionButton_item_selected(ns)
