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
	vd[NCONSTANTS.CFI_TIMESTAMP_RECIEVED] = Time.get_ticks_msec()*0.001
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
		get_parent().PF_framedatatoavatar(framestack[0])
		initialframestate = 2
		
	if len(framestack) > 0:
		Dframecount += 1
		if (Dframecount%60) == 0:
			print("Dmaxarrivaldelay ", Dmaxarrivaldelay)
			Dmaxarrivaldelay = framestack[0][NCONSTANTS.CFI_ARRIVALDELAY]
		else:
			Dmaxarrivaldelay = max(Dmaxarrivaldelay, framestack[0][NCONSTANTS.CFI_ARRIVALDELAY])
			
	var t = Time.get_ticks_msec()*0.001 - mintimestampoffset - laglatency
	var completedframeL = { }
	while len(framestack) > 0 and t > framestack[0][NCONSTANTS.CFI_TIMESTAMP]:
		var fd = framestack.pop_front()
		for k in fd:
			completedframe0[k] = fd[k]
			completedframeL[k] = fd[k]
		if len(framestack) == 0:
			get_parent().PF_framedatatoavatar(completedframeL)
			
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
					continue # v = v0  (filled in by completedframeL)
				elif ty == TYPE_INT:
					continue # v = v0  (filled in by completedframeL)
				elif ty == TYPE_QUATERNION:
					v = v0.slerp(v1, lam)
				else:
					v = lerp(v0, v1, lam)
				ld[k] = v
				completedframeL.erase(k)
		for k in completedframeL:
			ld[k] = completedframeL[k]
			
		get_parent().PF_framedatatoavatar(ld)
	

var audiostreamopuschunked : AudioStream = null
func _ready():
	var audiostreamplayer = get_node_or_null("../AudioStreamPlayer")
	if audiostreamplayer != null:
		audiostreamplayer.playing = true
		audiostreamopuschunked = audiostreamplayer.stream
		if audiostreamplayer.stream == null and ClassDB.can_instantiate("AudioStreamOpusChunked"):
			audiostreamplayer.stream = AudioStreamOpusChunked.new()
		if audiostreamplayer.stream != null and audiostreamplayer.stream.is_class("AudioStreamOpusChunked"):
			audiostreamopuschunked = audiostreamplayer.stream
		elif audiostreamplayer.stream != null:
			print("AudioStreamPlayer.stream must be type AudioStreamOpusChunked ", audiostreamplayer.stream)
	else:
		print("Need an AudioStreamPlayer node in RemotePlayer to do voip")


const asciiopenbrace = 123 # "{".to_ascii_buffer()[0]
const asciiclosebrace = 125 # "}".to_ascii_buffer()[0]
var lenchunkprefix = 0
var opusstreamcount = 0
var opusframecount = 0
var outoforderchunkqueue = [ null, null, null, null ]
func incomingaudiopacket(packet):
	if audiostreamopuschunked == null:
		return
	if len(packet) <= 3:
		print("Bad packet too short")
	elif packet[0] == asciiopenbrace and packet[-1] == asciiclosebrace:
		var h = JSON.parse_string(packet.get_string_from_ascii())
		if h != null:
			print("audio json packet ", h)
			get_node("../AudioStreamPlayer").playing = true
			if h.has("opusframesize"):
				if audiostreamopuschunked.opusframesize != h["opusframesize"] or \
				   audiostreamopuschunked.audiosamplesize != h["audiosamplesize"]:
					audiostreamopuschunked.opusframesize = h["opusframesize"]
					audiostreamopuschunked.audiosamplesize = h["audiosamplesize"]
					audiostreamopuschunked.opussamplerate = h["opussamplerate"]
					audiostreamopuschunked.audiosamplerate = h["audiosamplerate"]
				lenchunkprefix = int(h["lenchunkprefix"])
				opusstreamcount = int(h["opusstreamcount"])
				opusframecount = 0
				outoforderchunkqueue = [ null, null, null, null ]

	elif packet[1]&128 == (opusstreamcount%2)*128:
		var opusframecountI = packet[0] + (packet[1]&127)*256
		var opusframecountR = opusframecountI - opusframecount
		if opusframecountR < 0:
			print("framecount Wrapround 10mins? ", opusframecount, " ", opusframecountI)
			opusframecount = opusframecountI
			opusframecountR = 0
		if opusframecountR >= 0:
			while opusframecountR >= len(outoforderchunkqueue):
				print("shifting outoforderqueue ", opusframecountR, " ", ("null" if outoforderchunkqueue[0] == null else len(outoforderchunkqueue[0])))
				if outoforderchunkqueue[0] != null:
					audiostreamopuschunked.push_opus_packet(outoforderchunkqueue[0], lenchunkprefix, 0)
				elif outoforderchunkqueue[1] != null:
					audiostreamopuschunked.push_opus_packet(outoforderchunkqueue[1], lenchunkprefix, 1)
				outoforderchunkqueue.pop_front()
				outoforderchunkqueue.push_back(null)
				opusframecountR -= 1
				opusframecount += 1
			outoforderchunkqueue[opusframecountR] = packet
			while outoforderchunkqueue[0] != null:
				audiostreamopuschunked.push_opus_packet(outoforderchunkqueue.pop_front(), lenchunkprefix, 0)
				outoforderchunkqueue.push_back(null)
				opusframecount += 1
			
	else:
		print("dropping frame with opusstream number mismatch")
