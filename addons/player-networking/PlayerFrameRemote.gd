extends Node


var framestack = [ ]
var mintimestampoffset: float = 0.0
var laglatency = 0.2  # this needs to stay above almost all the arrivaldelay values
var initialframestate = 0
var completedframe0 = { }

var networkID = 0   # 0:unconnected, 1:server, -1:connecting, >1:connected to client
var logrecfile = null

var doppelgangerrecfile = null
var doppelgangerrectimeoffset = 0
var doppelgangernextrec = null
var NetworkGatewayForDoppelgangerReplay = null


var currentplayeranimation : Animation = null
var currentanimationlibrary : AnimationLibrary = null
var currentplayeranimationT0 = 0.0
var currentplayeranimationLookup = { }

var Danimatebyanimation = true
var initialframe = null

func Dclearcachesig():
	print("Dclearcachesig ", Time.get_ticks_msec())
func Dmixer_applied():
	print("Dmixerapplied ", Time.get_ticks_msec())
func Dmixer_updated():
	print("Dmixerupdated ", Time.get_ticks_msec())

		# we could make this tolerate out of order values
func networkedavatarthinnedframedata(vd):
	if logrecfile != null:
		logrecfile.store_var({"t":Time.get_ticks_msec()*0.001, "vd":vd})
	
	assert (not vd.has(NCONSTANTS.CFI_TIMESTAMP_F0))
	vd[NCONSTANTS.CFI_TIMESTAMP_RECIEVED] = Time.get_ticks_msec()*0.001
	var timestampoffset = vd[NCONSTANTS.CFI_TIMESTAMP_RECIEVED] - vd[NCONSTANTS.CFI_TIMESTAMP]
	if initialframestate == 0 or timestampoffset < mintimestampoffset:
		mintimestampoffset = timestampoffset
		print("new mintimeoffset ", timestampoffset)
		initialframestate = 1
	vd[NCONSTANTS.CFI_ARRIVALDELAY] = vd[NCONSTANTS.CFI_TIMESTAMP_RECIEVED] - mintimestampoffset - vd[NCONSTANTS.CFI_TIMESTAMPPREV]

	if Danimatebyanimation:
		if initialframe == null:
			initialframe = vd

		if currentplayeranimation == null:
			currentplayeranimation = Animation.new()
			currentplayeranimationT0 = vd[NCONSTANTS.CFI_TIMESTAMP]
			currentplayeranimationLookup = { }
			var currentplayeranimationlibrary = get_node("../AnimationPlayer").get_animation_library("")
			currentplayeranimation.length = 1
			currentplayeranimationlibrary.add_animation("cpa1", currentplayeranimation)
			get_node("../AnimationPlayer").play("cpa1")
			get_node("../AnimationPlayer").pause()
			get_node("../AnimationPlayer").caches_cleared.connect(Dclearcachesig)
			get_node("../AnimationPlayer").mixer_applied.connect(Dmixer_applied)
			get_node("../AnimationPlayer").mixer_updated.connect(Dmixer_updated)

			
		for k in vd:
			var i = currentplayeranimationLookup.get(k, -1)
			if i == -1:
				if k == NCONSTANTS.CFI_RECT_POSITION:
					i = currentplayeranimation.add_track(Animation.TYPE_VALUE)
					currentplayeranimation.track_set_path(i, ".:position")
				elif k == NCONSTANTS.CFI_VISIBLE:
					i = currentplayeranimation.add_track(Animation.TYPE_VALUE)
					currentplayeranimation.track_set_path(i, ".:visible")
				elif k == NCONSTANTS.CFI_SPEAKING:
					i = currentplayeranimation.add_track(Animation.TYPE_VALUE)
					currentplayeranimation.track_set_path(i, "SpeakingIcon`:visible")
				else:
					continue
				currentplayeranimationLookup[k] = i
			var kt = vd[NCONSTANTS.CFI_TIMESTAMP] - currentplayeranimationT0
			print(kt, "insertkey ", k)
			currentplayeranimation.track_insert_key(i, kt, vd[k])
			print(" Dinsertkey ")
			if kt + 1 > currentplayeranimation.length:
				currentplayeranimation.length = kt + 1
	else:
		framestack.push_back(vd)

var Dframecount = 0
var Dmaxarrivaldelay = 0
func _process(delta):
	var Ttime = Time.get_ticks_msec()*0.001
	if doppelgangerrecfile != null and doppelgangernextrec != null:
		if doppelgangerrectimeoffset + Ttime > doppelgangernextrec.t:
			if doppelgangernextrec.has("vd"):
				networkedavatarthinnedframedata(doppelgangernextrec["vd"])
				doppelgangernextrec = doppelgangerrecfile.get_var()
			elif doppelgangernextrec.has("au"):
				incomingaudiopacket(doppelgangernextrec["au"])
				doppelgangernextrec = doppelgangerrecfile.get_var()
			else:
				assert (doppelgangernextrec.has("END"))
				doppelgangernextrec = null
				print("logrec replay ended, removing doppelganger")
				NetworkGatewayForDoppelgangerReplay.DoppelgangerPanel.get_node("hbox/VBox_enable/DoppelgangerEnable").button_pressed = false
				
	if Danimatebyanimation:
		if initialframestate == 1 and initialframe != null:
			get_parent().PF_framedatatoavatar(initialframe)
			initialframestate = 2

		# mintimestampoffset = timestampreceived(~Ttime) - timestampsent
		var t = Ttime - mintimestampoffset - laglatency
		var kt = t - currentplayeranimationT0
		get_node("../AnimationPlayer").seek(kt, true)
		return

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
			
	var t = Ttime - mintimestampoffset - laglatency
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
			
		ld[NCONSTANTS.CFI_SPEAKING] = audiostreamopuschunked != null and audiostreamopuschunked.queue_length_frames() > 0

		get_parent().PF_framedatatoavatar(ld)


var audiostreamopuschunked : AudioStream = null
func _ready():
	var audiostreamplayer = get_node_or_null("../AudioStreamPlayer")
	if audiostreamplayer != null:
		audiostreamplayer.playing = true
		audiostreamopuschunked = audiostreamplayer.stream
		if audiostreamplayer.stream == null and ClassDB.can_instantiate("AudioStreamOpusChunked"):
			audiostreamplayer.stream = ClassDB.instantiate("AudioStreamOpusChunked")
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
var Dbatchinginitialpackets = false
func incomingaudiopacket(packet):
	if logrecfile != null:
		logrecfile.store_var({"t":Time.get_ticks_msec()*0.001, "au":packet})
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
				opusframecount = -1
				Dbatchinginitialpackets = (opusframecount != 0)
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
				if not Dbatchinginitialpackets:
					print("shifting outoforderqueue ", opusframecountR, " ", ("null" if outoforderchunkqueue[0] == null else len(outoforderchunkqueue[0])))
				else:
					Dbatchinginitialpackets = false
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
