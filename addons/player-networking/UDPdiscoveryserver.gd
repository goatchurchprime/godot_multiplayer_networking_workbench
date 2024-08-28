extends HBoxContainer

var udpdiscoveryport = 4546
const broadcastudpipnum = "255.255.255.255"
var udpdiscoverybroadcasterperiod = 2.0
const broadcastserverheader = "GodotServer_here!"
var udpdiscoverybroadcasterperiodtimer = udpdiscoverybroadcasterperiod
var broadcastservermsg = ""

func _ready():
	set_process(false)


func startUDPbroadcasting():
	udpdiscoveryport = int(get_node("../broadcastport").text)
	get_node("../broadcastport").editable = false
	udpdiscoverybroadcasterperiod = float($broadcastperiod.text)
	udpdiscoverybroadcasterperiodtimer = udpdiscoverybroadcasterperiod
	$broadcastperiod.editable = false
	get_node("../udpenabled").disabled = true
	print("IP.get_local_interfaces...")
	for localinterfaces in IP.get_local_interfaces():
		print("ii", localinterfaces["name"], " ", localinterfaces["friendly"], " ", localinterfaces["addresses"])
	var likelyserveraddresses = [ ]
	for a in IP.get_local_addresses():
		var la = a.split(".")
		if len(la) == 4:
			if int(la[0]) == 10 or int(la[0]) == 192:
				likelyserveraddresses.push_back(a)
	print("likelyserveraddresses ", likelyserveraddresses)
	broadcastservermsg = broadcastserverheader + " @" + ",".join(PackedStringArray(likelyserveraddresses))
	print("UDP broadcast message: ", broadcastservermsg)
	set_process(true)

func stopUDPbroadcasting():
	set_process(false)
	get_node("../broadcastport").editable = true
	$broadcastperiod.editable = true
	get_node("../udpenabled").disabled = false
	
func _process(delta):
	udpdiscoverybroadcasterperiodtimer -= delta
	if udpdiscoverybroadcasterperiodtimer < 0:
		var udpdiscoverybroadcaster = PacketPeerUDP.new()
		udpdiscoverybroadcaster.set_broadcast_enabled(true)
		var err0 = udpdiscoverybroadcaster.set_dest_address(broadcastudpipnum, udpdiscoveryport)
		var err1 = udpdiscoverybroadcaster.put_packet(broadcastservermsg.to_utf8_buffer())
		if err0 != 0 or err1 != 0:
			print("udpdiscoverybroadcaster error ", err0, " ", err1)
		udpdiscoverybroadcasterperiodtimer = udpdiscoverybroadcasterperiod
		$ColorRect.visible = not $ColorRect.visible
