extends Node

var doppelgangernode = null

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


var framedividerVal = 5
var framedividerCount = framedividerVal
var DframereportCount = 0
var Dcumulativebytes = 0
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
		print("Frame bytes: ", Dcumulativebytes)
		Dcumulativebytes= 0
		DframereportCount = 0
	
	if get_parent().networkID >= 1:
		vd[CFI_TIMESTAMP] = tstamp
		rpc("networkedavatarthinnedframedata", vd)
		
	if doppelgangernode != null:
		vd[CFI_TIMESTAMP] = tstamp + 100
		get_parent().changethinnedframedatafordoppelganger(vd)
		doppelgangernode.get_node("RemotePlayerFrame").call_deferred("networkedavatarthinnedframedata", vd)



