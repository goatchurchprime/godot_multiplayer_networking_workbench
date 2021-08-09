extends Node

export var udpdiscoveryport = 4546
const broadcastudpipnum = "255.255.255.255"
const udpdiscoverybroadcasterperiod = 2.0
const broadcastservermsg = "GodotServer_here!"

var udpdiscoverybroadcasterperiodtimer = udpdiscoverybroadcasterperiod
var udpdiscoveryreceivingserver = null

func _ready():
	set_process(false)

var broadcasting = false
func start_udp_localIP_discovery_signals(broadcasting_IPnumber_to_udp):
	if not broadcasting_IPnumber_to_udp:
		udpdiscoveryreceivingserver = UDPServer.new()
		udpdiscoveryreceivingserver.listen(udpdiscoveryport)
	set_process(true)

func stop_udp_localIP_discovery_signals():
	if udpdiscoveryreceivingserver != null:
		udpdiscoveryreceivingserver.stop()
		udpdiscoveryreceivingserver = null
	set_process(false)
	
func _process(delta):
	if udpdiscoveryreceivingserver == null:
		udpdiscoverybroadcasterperiodtimer -= delta
		if udpdiscoverybroadcasterperiodtimer < 0:
			var udpdiscoverybroadcaster = PacketPeerUDP.new()
			udpdiscoverybroadcaster.set_broadcast_enabled(true)
			var err0 = udpdiscoverybroadcaster.set_dest_address(broadcastudpipnum, udpdiscoveryport)
			var err1 = udpdiscoverybroadcaster.put_packet((broadcastservermsg+" "+str(12)).to_utf8())
			if err0 != 0 or err1 != 0:
				print("udpdiscoverybroadcaster error ", err0, " ", err1)
			udpdiscoverybroadcasterperiodtimer = udpdiscoverybroadcasterperiod

	else:
		udpdiscoveryreceivingserver.poll()
		if udpdiscoveryreceivingserver.is_connection_available():
			var peer = udpdiscoveryreceivingserver.take_connection()
			var pkt = peer.get_packet()
			var spkt = pkt.get_string_from_utf8().split(" ")
			print("Received: ", spkt, " from ", peer.get_packet_ip())
			if spkt[0] == broadcastservermsg:
				get_parent().udpreceivedipnumber(peer.get_packet_ip())
