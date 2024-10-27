extends Node

var doppelgangernode = null
var NetworkGatewayForDoppelganger = null
var PlayerConnections = null

var networkID = 0   # 0:unconnected, 1:server, >1:connected as client
var logrecfile = null

var PlayerAnimation : AnimationPlayer = null
var templateanimation : Animation = null
var currentrecordinganimation : Animation = null
var currentrecordinganimationT0 = 0.0
const animationtimerunoff = 10.0

var DframereportCount = 0
var Dcumulativebytes = 0
var Dframebytesprev = 0

var heartbeatfullframeseconds = 5.0
var minframeseconds = 0.1
var timestampprev = 0.0

var bawaitingspawninfofromserver = false

func setupanimationtrackrecorder():
	var ad = snapshotallanimatedtracks()
	var currentrecordinganimationlibrary = PlayerAnimation.get_animation_library("playeral")
	currentrecordinganimation = templateanimation.duplicate()
	currentrecordinganimationT0 = ad[NCONSTANTS.CFI_TIMESTAMP]
	currentrecordinganimation.length = animationtimerunoff
	currentrecordinganimationlibrary.add_animation("recordanim1", currentrecordinganimation)
	for i in range(currentrecordinganimation.get_track_count()):
		currentrecordinganimation.track_insert_key(i, 0, ad[NCONSTANTS.CFI_ANIMTRACKS + i])
	
func _ready():
	PlayerAnimation = get_node("../PlayerAnimation")
	var currentrecordinganimationlibrary = PlayerAnimation.get_animation_library("playeral")
	templateanimation = currentrecordinganimationlibrary.get_animation("trackstemplate")
	call_deferred("setupanimationtrackrecorder")

func setlocalframenetworkidandname(lnetworkID):
	networkID = lnetworkID
	get_parent().set_name(PlayerConnections.playernamefromnetworkid(networkID)) 

func trackpropertysignificantlychanged(v, v0):
	var ty = typeof(v)
	assert (ty == typeof(v0))
	if ty == TYPE_QUATERNION:
		var dv = v0*v.inverse()
		return (dv.w < 0.9994)  # 2 degrees
	elif ty == TYPE_VECTOR3:
		var dv = v0 - v
		return (dv.length() > 0.002)
	elif ty == TYPE_VECTOR2:
		var dv = v0 - v
		return (dv.length() > 0.02)
	elif ty == TYPE_INT:
		return (v0 != v)
	elif ty == TYPE_BOOL:
		return (v0 != v)
	elif ty == TYPE_FLOAT:
		return (abs(v0 - v) > 0.001)
	elif ty == TYPE_STRING:
		return (v0 != v)
	else:
		print("Unknown type ", ty)
	return true

func snapshotallanimatedtracks():
	var ad = { }
	for i in range(templateanimation.get_track_count()):
		var nodepath = templateanimation.track_get_path(i)
		var noderesource = PlayerAnimation.get_parent().get_node_and_resource(nodepath)
		assert (noderesource[1] == null)
		var propertyval = noderesource[0].get_indexed(noderesource[2])
		ad[NCONSTANTS.CFI_ANIMTRACKS + i] = propertyval
	ad[NCONSTANTS.CFI_TIMESTAMP] = Time.get_ticks_msec()*0.001
	return ad
	
func recordthinnedanimation(t, brecordalltracks):
	var ad = { }
	for i in range(currentrecordinganimation.get_track_count()):
		var nodepath = currentrecordinganimation.track_get_path(i)
		var noderesource = PlayerAnimation.get_parent().get_node_and_resource(nodepath)
		assert (noderesource[1] == null)
		var propertyval = noderesource[0].get_indexed(noderesource[2])
		var binsertkey = brecordalltracks
		if not brecordalltracks:
			var kn = currentrecordinganimation.track_get_key_count(i)
			var prevpropertyval = currentrecordinganimation.track_get_key_value(i, kn-1)
			binsertkey = trackpropertysignificantlychanged(propertyval, prevpropertyval)
		if binsertkey:
			currentrecordinganimation.track_insert_key(i, t, propertyval)
			ad[NCONSTANTS.CFI_ANIMTRACKS + i] = propertyval
	currentrecordinganimation.length = t + animationtimerunoff
	return ad

func datafornewconnectedplayer(bfordoppelganger):
	var avatardata = { "avatarsceneresource":get_parent().scene_file_path
					 }
	avatardata["snapshottracks"] = snapshotallanimatedtracks()
	if not bfordoppelganger:
		avatardata["Dplayernodename"] = get_parent().get_name()
		avatardata["Dnetworkid"] = networkID
	return avatardata


func _process(delta):
	get_parent().PF_processlocalavatarposition(delta)

	var tstamp = Time.get_ticks_msec()*0.001
	var dft = tstamp - timestampprev
	if dft < minframeseconds:
		return

	var brecordalltracks = false
	#if dft >= heartbeatfullframeseconds:
	#	brecordalltracks = true
	if currentrecordinganimation == null:
		return
	var vd = recordthinnedanimation(tstamp - currentrecordinganimationT0, brecordalltracks)
	if len(vd) == 0:
		return
		
	vd[NCONSTANTS.CFI_TIMESTAMPPREV] = timestampprev
	vd[NCONSTANTS.CFI_TIMESTAMP] = tstamp
	timestampprev = tstamp	

	Dcumulativebytes += len(var_to_bytes(vd))
	DframereportCount += 1
	if DframereportCount == 10:
		if Dcumulativebytes != Dframebytesprev:
			print("Frame bytes: ", Dcumulativebytes)
			Dframebytesprev = Dcumulativebytes
		Dcumulativebytes= 0
		DframereportCount = 0

	if bawaitingspawninfofromserver:
		return

	if networkID >= 1:
		PlayerConnections.rpc("RPC_networkedavatarthinnedframedata", vd)
		
	if doppelgangernode != null and NetworkGatewayForDoppelganger != null:
		var doppelnetoffset = NetworkGatewayForDoppelganger.DoppelgangerPanel.getnetoffset()
		get_parent().PF_changethinnedframedatafordoppelganger(vd, doppelnetoffset, false)
		var doppelgangerdelay = NetworkGatewayForDoppelganger.getrandomdoppelgangerdelay()
		if doppelgangerdelay != -1.0:
			await get_tree().create_timer(doppelgangerdelay*0.001).timeout
			if doppelgangernode != null:
				if doppelgangernode.has_method("networkedavatarthinnedframedataANIM"):
					doppelgangernode.networkedavatarthinnedframedataANIM(vd)
				else:
					doppelgangernode.get_node("PlayerFrame").networkedavatarthinnedframedata(vd)

	if logrecfile != null:
		logrecfile.store_var({"t":Time.get_ticks_msec()*0.001, "vd":vd})


func transmitaudiopacket(packet):
	if networkID >= 1:
		PlayerConnections.rpc("RPC_incomingaudiopacket", packet)
	if doppelgangernode != null and NetworkGatewayForDoppelganger != null:
		var doppelnetoffset = NetworkGatewayForDoppelganger.DoppelgangerPanel.getnetoffset()
		var doppelgangerdelay = NetworkGatewayForDoppelganger.getrandomdoppelgangerdelay()
		if doppelgangerdelay != -1.0:
			await get_tree().create_timer(doppelgangerdelay*0.001).timeout
			if doppelgangernode != null:
				doppelgangernode.get_node("PlayerFrame").incomingaudiopacket(packet)
		else:
			print("dropaudioframe")
	if logrecfile != null:
		logrecfile.store_var({"t":Time.get_ticks_msec()*0.001, "au":packet})
