extends Node

var framestack = [ ]
var mintimestampoffset: float = 0.0
var laglatency = 0.2  # this needs to stay above almost all the arrivaldelay values
var initialframestate = 0
var completedframe0 = { }

var networkID = 0   # 1:server, >1:connected as client
var logrecfile = null

var doppelgangerrecfile = null
var doppelgangerrectimeoffset = 0
var doppelgangernextrec = null
var NetworkGatewayForDoppelgangerReplay = null


var PlayerAnimation : AnimationPlayer = null
var currentplayeranimation : Animation = null
var currentplayeranimationT0 = 0.0
const animationtimerunoff = 1.0

var Danimatebyanimation = true
var initialframe = null

func Dclearcachesig():
	pass # print("Dclearcachesig ", Time.get_ticks_msec())
func Dmixer_updated():
	print("Dmixerupdated ", Time.get_ticks_msec())

func setupanimationtracks(vd):
	PlayerAnimation = get_node("../PlayerAnimation")
	var currentplayeranimationlibrary = PlayerAnimation.get_animation_library("playeral")
	var templateanimation : Animation = currentplayeranimationlibrary.get_animation("trackstemplate")
	currentplayeranimation = templateanimation.duplicate()
	currentplayeranimationT0 = vd[NCONSTANTS.CFI_TIMESTAMP]
	currentplayeranimation.length = animationtimerunoff
	currentplayeranimationlibrary.add_animation("playanim1", currentplayeranimation)
	PlayerAnimation.play("playeral/playanim1")
	PlayerAnimation.pause()
	PlayerAnimation.caches_cleared.connect(Dclearcachesig)
	PlayerAnimation.mixer_updated.connect(Dmixer_updated)

func networkedavatarthinnedframedata(vd):
		# we could make this tolerate out of order values
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

	if currentplayeranimation == null:
		setupanimationtracks(vd)
	if currentplayeranimation != null:
		for k in vd:
			if k >= NCONSTANTS.CFI_ANIMTRACKS:
				var i = k - NCONSTANTS.CFI_ANIMTRACKS
				var kt = vd[NCONSTANTS.CFI_TIMESTAMP] - currentplayeranimationT0
				#print(kt, "insertkey ", k)
				currentplayeranimation.track_insert_key(i, kt, vd[k])
				#print(" Dinsertkey ")
				if kt + animationtimerunoff > currentplayeranimation.length:
					currentplayeranimation.length = kt + animationtimerunoff


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
				NetworkGatewayForDoppelgangerReplay.DoppelgangerPanel.get_node("hbox/VBox_enable/DoppelgangerEnable").button_pressed = false
				
	if currentplayeranimation != null:
		var t = Ttime - mintimestampoffset - laglatency
		var kt = t - currentplayeranimationT0
		PlayerAnimation.seek(kt, true)


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
