extends Node

var doppelgangernode = null
var NetworkGatewayForDoppelganger = null
var PlayerConnections = null

const CFI_TIMESTAMP 		= -1 
const CFI_TIMESTAMPPREV 	= -2

static func thinframedata(fd0, fd, bnothinning):
	var vd = { }
	for k in fd:
		assert (typeof(k) != TYPE_INT or k != CFI_TIMESTAMP)
		var v = fd[k]
		var v0 = fd0.get(k, null)
		if v0 != null:
			var ty = typeof(v)
			if bnothinning:
				pass
			elif ty == TYPE_QUAT:
				var dv = v0*v.inverse()
				if dv.w > 0.995:
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
			elif ty == TYPE_REAL:
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

var framedata0 = { CFI_TIMESTAMP:0.0 }
func _process(delta):
	get_parent().processlocalavatarposition(delta)

	var tstamp = OS.get_ticks_msec()*0.001
	var dft = tstamp - framedata0[CFI_TIMESTAMP]
	if dft < minframeseconds:
		return
	var fd = get_parent().avatartoframedata()
	var vd = thinframedata(framedata0, fd, (dft >= heartbeatfullframeseconds))
	if len(vd) == 0:
		return
	vd[CFI_TIMESTAMPPREV] = framedata0[CFI_TIMESTAMP]
	vd[CFI_TIMESTAMP] = tstamp
	framedata0[CFI_TIMESTAMP] = tstamp
	
	Dcumulativebytes += len(var2bytes(vd))
	DframereportCount += 1
	if DframereportCount == 10:
		if Dcumulativebytes != Dframebytesprev:
			print("Frame bytes: ", Dcumulativebytes)
			Dframebytesprev = Dcumulativebytes
		Dcumulativebytes= 0
		DframereportCount = 0

	PlayerConnections.get_node("../TimelineVisualizer/Viewport/TimelineDiagram").marknetworkdataat(vd)
	
	if get_parent().networkID >= 1:
		vd["playernodename"] = get_parent().get_name()
		PlayerConnections.rpc("networkedavatarthinnedframedataPC", vd)
		
	if doppelgangernode != null:
		var doppelnetoffset = float(NetworkGatewayForDoppelganger.get_node("DoppelgangerPanel/netoffset").text)*0.001
		vd[CFI_TIMESTAMP] += doppelnetoffset
		vd[CFI_TIMESTAMPPREV] += doppelnetoffset
		vd["playernodename"] = "Doppelganger"
		get_parent().changethinnedframedatafordoppelganger(vd)
		var doppelgangerdelay = NetworkGatewayForDoppelganger.getrandomdoppelgangerdelay()
		if doppelgangerdelay != -1.0:
			yield(get_tree().create_timer(doppelgangerdelay*0.001), "timeout")
			if doppelgangernode != null:
				vd["received_timestamp"] = OS.get_ticks_msec()*0.001
				doppelgangernode.get_node("PlayerFrame").networkedavatarthinnedframedata(vd)
				PlayerConnections.get_node("../TimelineVisualizer/Viewport/TimelineDiagram").marknetworkdataat(vd)



