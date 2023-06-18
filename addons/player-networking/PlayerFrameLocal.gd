extends Node

var doppelgangernode = null
var NetworkGatewayForDoppelganger = null
var PlayerConnections = null

var networkID = 0   # 0:unconnected, 1:server, -1:connecting, >1:connected to client

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
	get_parent().PAV_processlocalavatarposition(delta)

	var tstamp = Time.get_ticks_msec()*0.001
	var dft = tstamp - framedata0[NCONSTANTS.CFI_TIMESTAMP]
	if dft < minframeseconds:
		return
	framedata0[NCONSTANTS.CFI_TIMESTAMPPREV] = framedata0[NCONSTANTS.CFI_TIMESTAMP_F0]
	framedata0[NCONSTANTS.CFI_TIMESTAMP_F0] = tstamp

	var fd = get_parent().PAV_avatartoframedata()
	var vd = thinframedata_updatef0(framedata0, fd, (dft >= heartbeatfullframeseconds))
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

	if PlayerConnections.get_node("../TimelineVisualizer").visible:
		PlayerConnections.get_node("../TimelineVisualizer/SubViewport/TimelineDiagram").marknetworkdataat(vd, "LocalPlayer")
	
	if networkID >= 1:
		vd[NCONSTANTS.CFI_PLAYER_NODENAME] = get_parent().get_name()
		PlayerConnections.rpc("networkedavatarthinnedframedataPC", vd)
		
	if doppelgangernode != null:
		var doppelnetoffset = float(NetworkGatewayForDoppelganger.get_node("DoppelgangerPanel/netoffset").text)*0.001
		get_parent().PAV_changethinnedframedatafordoppelganger(vd, doppelnetoffset, false)
		var doppelgangerdelay = NetworkGatewayForDoppelganger.getrandomdoppelgangerdelay()
		if doppelgangerdelay != -1.0:
			await get_tree().create_timer(doppelgangerdelay*0.001).timeout
			if doppelgangernode != null:
				doppelgangernode.get_node("PlayerFrame").networkedavatarthinnedframedata(vd)
				if PlayerConnections.get_node("../TimelineVisualizer").visible:
					PlayerConnections.get_node("../TimelineVisualizer/SubViewport/TimelineDiagram").marknetworkdataat(vd, doppelgangernode.get_name())



