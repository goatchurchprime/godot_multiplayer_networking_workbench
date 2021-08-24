extends Control

var udpdiscoveryport = 4546
const broadcastudpipnum = "255.255.255.255"
var udpdiscoverybroadcasterperiod = 2.0
const broadcastservermsg = "GodotServer_here!"
var udpdiscoverybroadcasterperiodtimer = udpdiscoverybroadcasterperiod

func _ready():
	set_process(false)

func startUDPbroadcasting():
	udpdiscoveryport = int(get_node("../broadcastport").text)
	get_node("../broadcastport").editable = false
	udpdiscoverybroadcasterperiod = float($broadcastperiod.text)
	udpdiscoverybroadcasterperiodtimer = udpdiscoverybroadcasterperiod
	$broadcastperiod.editable = false
	get_node("../udpenabled").disabled = true
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
		var err1 = udpdiscoverybroadcaster.put_packet((broadcastservermsg+" "+str(12)).to_utf8())
		if err0 != 0 or err1 != 0:
			print("udpdiscoverybroadcaster error ", err0, " ", err1)
		udpdiscoverybroadcasterperiodtimer = udpdiscoverybroadcasterperiod
		$ColorRect.visible = not $ColorRect.visible
