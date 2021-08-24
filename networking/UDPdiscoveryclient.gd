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
			get_node("../..").udpreceivedipnumber(peer.get_packet_ip())
