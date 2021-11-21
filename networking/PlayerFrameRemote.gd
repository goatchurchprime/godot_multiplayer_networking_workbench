extends Node


var framestack = [ ]
var mintimestampoffset = 0.0
var laglatency = 0.2

func networkedavatarthinnedframedata(vd):
	assert (not vd.has(NCONSTANTS.CFI_TIMESTAMP_F0))
	vd[NCONSTANTS.CFI_TIMESTAMP_RECIEVED] = OS.get_ticks_msec()*0.001
	var timestampoffset = vd[NCONSTANTS.CFI_TIMESTAMP_RECIEVED] - vd[NCONSTANTS.CFI_TIMESTAMP]
	if len(framestack) == 0 or timestampoffset < mintimestampoffset:
		mintimestampoffset = timestampoffset
		print("new mintimeoffset ", timestampoffset)

	if vd.has(NCONSTANTS.CFI_TIMESTAMPPREV) and len(framestack) != 0 and framestack[-1][NCONSTANTS.CFI_TIMESTAMP] != vd[NCONSTANTS.CFI_TIMESTAMPPREV]:
		framestack.push_back(framestack[-1].duplicate())
		framestack[-1].erase(NCONSTANTS.CFI_TIMESTAMP_RECIEVED)
		framestack[-1][NCONSTANTS.CFI_TIMESTAMP] = vd[NCONSTANTS.CFI_TIMESTAMPPREV]
		print("ff ", framestack[-1])

	var fd = framestack[-1].duplicate() if len(framestack) != 0 else { }
	for k in vd:
		fd[k] = vd[k]
	framestack.push_back(fd)

func _process(delta):
	var t = OS.get_ticks_msec()*0.001 - mintimestampoffset - laglatency
	while len(framestack) >= 2 and t > framestack[1][NCONSTANTS.CFI_TIMESTAMP]:
		print("kk ", framestack[0])
		framestack.pop_front()
	if len(framestack) == 1:
		get_parent().framedatatoavatar(framestack[0])
	elif len(framestack) >= 2:
		var lam = inverse_lerp(framestack[0][NCONSTANTS.CFI_TIMESTAMP], framestack[1][NCONSTANTS.CFI_TIMESTAMP], t)
		var ld = { }
		for k in framestack[0]:
			if k > NCONSTANTS.CFI_ZERO and framestack[1].has(k):
				var v0 = framestack[0][k]
				var v1 = framestack[1][k]
				var v = null
				var ty = typeof(v0)
				if ty == TYPE_BOOL:
					v = v0
				elif ty == TYPE_INT:
					v = v0
				elif ty == TYPE_QUAT:
					var dv = v0*v1.inverse()
					print(dv, "something special")
				else:
					v = lerp(v0, v1, lam)
				ld[k] = v
					
		get_parent().framedatatoavatar(ld)
	
