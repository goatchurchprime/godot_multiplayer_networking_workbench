extends Node

var doppelgangernode = null
var NetworkGatewayForDoppelganger = null
var PlayerConnections = null

var networkID = 0   # 0:unconnected, 1:server, -1:connecting, >1:connected to client
var logrecfile = null

static func thinframedata_updatef0(fd0, fd, bnothinning):
	var vd = { }
	for k in fd:
		assert (k != NCONSTANTS.CFI_TIMESTAMP)
		var v = fd[k]
		var v0 = fd0.get(k, null)
		if v0 != null:
			var ty = typeof(v)
			if bnothinning:
				pass
			elif ty == TYPE_QUATERNION:
				var dv = v0*v.inverse()
				if dv.w > 0.9994:  # 2 degrees
					v = null
			elif ty == TYPE_VECTOR3:
				var dv = v0 - v
				if dv.length() < 0.002:
					v = null
			elif ty == TYPE_VECTOR2:
				var dv = v0 - v
				if dv.length() < 0.02:
					v = null
			elif ty == TYPE_INT:
				if v0 == v:
					v = null
			elif ty == TYPE_BOOL:
				if v0 == v:
					v = null
			elif ty == TYPE_FLOAT:
				if abs(v0 - v) < 0.001:
					v = null
			else:
				print("unknown type ", ty, " ", v)
		if v != null:
			vd[k] = v
			fd0[k] = v
	return vd

var framedividerVal = 10
var framedividerCount = framedividerVal
var DframereportCount = 0
var Dcumulativebytes = 0
var Dframebytesprev = 0

var heartbeatfullframeseconds = 5.0
var minframeseconds = 0.1

var framedata0 = { NCONSTANTS.CFI_TIMESTAMP:0.0, NCONSTANTS.CFI_TIMESTAMP_F0:0.0 }
func _process(delta):
	if not get_parent().PF_processlocalavatarposition(delta):
		return

	var tstamp = Time.get_ticks_msec()*0.001
	var dft = tstamp - framedata0[NCONSTANTS.CFI_TIMESTAMP]
	if dft < minframeseconds:
		return
	framedata0[NCONSTANTS.CFI_TIMESTAMPPREV] = framedata0[NCONSTANTS.CFI_TIMESTAMP_F0]
	framedata0[NCONSTANTS.CFI_TIMESTAMP_F0] = tstamp

	var fd = get_parent().PF_avatartoframedata()
	var bnothinning = (dft >= heartbeatfullframeseconds) or (fd.get(NCONSTANTS.CFI_NOTHINFRAME) == 1)
	var vd = thinframedata_updatef0(framedata0, fd, bnothinning)
	if len(vd) == 0:
		return
	framedata0[NCONSTANTS.CFI_TIMESTAMP] = tstamp
	vd[NCONSTANTS.CFI_TIMESTAMPPREV] = framedata0[NCONSTANTS.CFI_TIMESTAMPPREV]
	vd[NCONSTANTS.CFI_TIMESTAMP] = tstamp
	#print("vv ", vd)
	
	Dcumulativebytes += len(var_to_bytes(vd))
	DframereportCount += 1
	if DframereportCount == 10:
		if Dcumulativebytes != Dframebytesprev:
			print("Frame bytes: ", Dcumulativebytes)
			Dframebytesprev = Dcumulativebytes
		Dcumulativebytes= 0
		DframereportCount = 0

	if networkID >= 1:
		vd[NCONSTANTS.CFI_PLAYER_NODENAME] = get_parent().get_name()
		PlayerConnections.rpc("RPCnetworkedavatarthinnedframedataPC", vd)
		
	if doppelgangernode != null:
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
		PlayerConnections.rpc("RPCincomingaudiopacket", packet)
	if doppelgangernode != null:
		var doppelnetoffset = NetworkGatewayForDoppelganger.DoppelgangerPanel.getnetoffset()
		var doppelgangerdelay = NetworkGatewayForDoppelganger.getrandomdoppelgangerdelay()
		if doppelgangerdelay != -1.0:
			await get_tree().create_timer(doppelgangerdelay*0.001).timeout
			if doppelgangernode != null:
				doppelgangernode.get_node("PlayerFrame").incomingaudiopacket(packet)
		else:
			print("dropaudframe")
	if logrecfile != null:
		logrecfile.store_var({"t":Time.get_ticks_msec()*0.001, "au":packet})
