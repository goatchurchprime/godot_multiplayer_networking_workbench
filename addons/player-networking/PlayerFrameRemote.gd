extends Node


var framestack = [ ]
var mintimestampoffset: float = 0.0
var laglatency = 0.2  # this needs to stay above almost all the arrivaldelay values
var initialframestate = 0
var completedframe0 = { }

var networkID = 0   # 0:unconnected, 1:server, -1:connecting, >1:connected to client

		# we could make this tolerate out of order values
func networkedavatarthinnedframedata(vd):
	assert (not vd.has(NCONSTANTS.CFI_TIMESTAMP_F0))
	vd[NCONSTANTS.CFI_TIMESTAMP_RECIEVED] = OS.get_ticks_msec()*0.001
	var timestampoffset = vd[NCONSTANTS.CFI_TIMESTAMP_RECIEVED] - vd[NCONSTANTS.CFI_TIMESTAMP]
	if initialframestate == 0 or timestampoffset < mintimestampoffset:
		mintimestampoffset = timestampoffset
		print("new mintimeoffset ", timestampoffset)
		initialframestate = 1
	vd[NCONSTANTS.CFI_ARRIVALDELAY] = vd[NCONSTANTS.CFI_TIMESTAMP_RECIEVED] - mintimestampoffset - vd[NCONSTANTS.CFI_TIMESTAMPPREV]
	framestack.push_back(vd)
	
var Dframecount = 0
var Dmaxarrivaldelay = 0

func _process(delta):
	if initialframestate == 1 and len(framestack) > 0:
		get_parent().framedatatoavatar(framestack[0])
		initialframestate = 2
		
	if len(framestack) > 0:
		Dframecount += 1
		if (Dframecount%60) == 0:
			print("Dmaxarrivaldelay ", Dmaxarrivaldelay)
			Dmaxarrivaldelay = framestack[0][NCONSTANTS.CFI_ARRIVALDELAY]
		else:
			Dmaxarrivaldelay = max(Dmaxarrivaldelay, framestack[0][NCONSTANTS.CFI_ARRIVALDELAY])
			

	var t = OS.get_ticks_msec()*0.001 - mintimestampoffset - laglatency
	while len(framestack) > 0 and t > framestack[0][NCONSTANTS.CFI_TIMESTAMP]:
		var fd = framestack.pop_front()
		for k in fd:
			completedframe0[k] = fd[k]
		if len(framestack) == 0:
			get_parent().framedatatoavatar(fd)
			
	if len(framestack) > 0 and t > framestack[0][NCONSTANTS.CFI_TIMESTAMPPREV]:
		var lam = inverse_lerp(framestack[0][NCONSTANTS.CFI_TIMESTAMPPREV], framestack[0][NCONSTANTS.CFI_TIMESTAMP], t)
		var ld = { }
		for k in framestack[0]:
			if k > NCONSTANTS.CFI_ZERO and completedframe0.has(k):
				var v1 = framestack[0][k]
				var v0 = completedframe0[k]
				var v = null
				var ty = typeof(v1)
				if ty == TYPE_BOOL:
					v = v0
				elif ty == TYPE_INT:
					v = v0
				elif ty == TYPE_QUAT:
					v = v0.slerp(v1, lam)
				else:
					v = lerp(v0, v1, lam)
				ld[k] = v
					
		get_parent().framedatatoavatar(ld)
	
