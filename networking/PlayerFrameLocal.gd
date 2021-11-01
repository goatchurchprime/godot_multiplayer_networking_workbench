extends Node

var doppelgangernode = null
var NetworkGatewayForDoppelganger = null
var PlayerConnections = null

const CFI_TIMESTAMP 		= -1 

var framedata0 = { }
func thinframedata(fd):
	var vd = { }
	for k in fd:
		var v = fd[k]
		var v0 = framedata0.get(k, null)
		if v0 != null:
			var ty = typeof(v)
			if ty == TYPE_QUAT:
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
			elif ty == TYPE_REAL:
				if abs(v0 - v) < 0.001:
					v = null
			else:
				print("unknown type ", ty, " ", v)
		if v != null:
			vd[k] = v
			framedata0[k] = v
	return vd


var framedividerVal = 10
var framedividerCount = framedividerVal
var DframereportCount = 0
var Dcumulativebytes = 0
var Dframebytesprev = 0
func _process(delta):
	get_parent().processlocalavatarposition(delta)

	var tstamp = OS.get_ticks_msec()*0.001
	framedividerCount -= 1
	if framedividerCount > 0:
		return
	framedividerCount = framedividerVal

	var fd = get_parent().avatartoframedata()
	var vd = thinframedata(fd)
	
	Dcumulativebytes += len(var2bytes(vd))
	DframereportCount += 1
	if DframereportCount == 10:
		if Dcumulativebytes != Dframebytesprev:
			print("Frame bytes: ", Dcumulativebytes)
			Dframebytesprev = Dcumulativebytes
		Dcumulativebytes= 0
		DframereportCount = 0

	vd[CFI_TIMESTAMP] = tstamp
	PlayerConnections.get_node("../TimelineVisualizer/Viewport/TimelineDiagram").marknetworkdataat(vd)
	
	if get_parent().networkID >= 1:
		vd["playernodename"] = get_parent().get_name()
		PlayerConnections.rpc("networkedavatarthinnedframedataPC", vd)
		
	if doppelgangernode != null:
		vd[CFI_TIMESTAMP] = tstamp + int(NetworkGatewayForDoppelganger.get_node("DoppelgangerPanel/netoffset").text)
		vd["playernodename"] = "Doppelganger"
		get_parent().changethinnedframedatafordoppelganger(vd)
		var doppelgangerdelay = NetworkGatewayForDoppelganger.getrandomdoppelgangerdelay()
		if doppelgangerdelay != -1.0:
			yield(get_tree().create_timer(doppelgangerdelay*0.001), "timeout")
			if doppelgangernode != null:
				vd["received_timestamp"] = OS.get_ticks_msec()*0.001
				doppelgangernode.get_node("PlayerFrame").networkedavatarthinnedframedata(vd)
				PlayerConnections.get_node("../TimelineVisualizer/Viewport/TimelineDiagram").marknetworkdataat(vd)



