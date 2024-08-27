extends Control

var udpdiscoveryport = 4546
const broadcastudpipnum = "255.255.255.255"
const broadcastserverheader = "GodotServer_here!"
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
		if spkt[0] == broadcastserverheader:
			var likelyserveraddresses =  spkt[1].substr(1).split(",")  if len(spkt) > 1 and spkt[1][0] == "@"  else [ ]
			var NetworkGateway = get_node("../..")
			var NetworkOptions = NetworkGateway.NetworkOptions
			var receivedIPnumber = peer.get_packet_ip()
			if not (receivedIPnumber in likelyserveraddresses):
				likelyserveraddresses.push_back(receivedIPnumber)
			var listedserveraddresses = [ ]
			for i in range(NetworkGateway.NETWORK_OPTIONS.FIXED_URL, NetworkOptions.get_item_count()):
				listedserveraddresses.push_back(NetworkOptions.get_item_text(i))
			for likelyserveripaddress in likelyserveraddresses:
				if not (likelyserveripaddress in listedserveraddresses):
					NetworkOptions.add_item(likelyserveripaddress)
					listedserveraddresses.push_back(likelyserveripaddress)
			print("eeep", NetworkGateway.NetworkOptions.selected)
			NetworkGateway.selectandtrigger_networkoption(listedserveraddresses.find(likelyserveraddresses[0]) + NetworkGateway.NETWORK_OPTIONS.FIXED_URL)
