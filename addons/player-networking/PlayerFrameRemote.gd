extends Node

var mintimestampoffset: float = 0.0
var laglatency = 0.2  # this needs to stay above almost all the arrivaldelay values
var initialframestate = 0

var networkID = 0   # 1:server, >1:connected as client
var logrecfile = null

var doppelgangerrecfile = null
var doppelgangerrectimeoffset = 0
var doppelgangernextrec = null
var NetworkGatewayForDoppelgangerReplay = null


var PlayerAnimation : AnimationPlayer = null
var currentplayeranimation : Animation = null
var currentplayeranimationT0 = 0.0
const animationtimerunoff = 5.0

#frametimems = opusframesize*1000.0/opusframesize
var audioserveroutputlatency = 0.015
var audiobufferregulationtimeLow = 0.6
var audiobufferregulationtime = 1.2
var audiobufferregulationpitchlow = 1.4
var audiobufferregulationpitch = 2.0
var audiobufferpitchscale = 1.0

func Dclearcachesig():
	pass # print("Dclearcachesig ", Time.get_ticks_msec())
func Dmixer_updated():
	print("Dmixerupdated ", Time.get_ticks_msec())

func setupanimationtracks(vd):
	PlayerAnimation = get_node_or_null("../PlayerAnimation")
	if PlayerAnimation == null or not PlayerAnimation.is_class("AnimationMixer"):
		printerr("PlayerScene must have PlayerAnimation:AnimationMixer")
	var currentplayeranimationlibrary = PlayerAnimation.get_animation_library("playeral")
	if currentplayeranimationlibrary == null:
		printerr("PlayerScene.PlayerAnimation must have animation library 'playeral'")
	if not currentplayeranimationlibrary.resource_local_to_scene:  # Avoids crash, see below
		printerr("PlayerScene.PlayerAnimation library 'playeral' must be local to scene")
		assert (false)
		
	var templateanimation : Animation = currentplayeranimationlibrary.get_animation("trackstemplate")
	if templateanimation == null:
		printerr("PlayerScene.PlayerAnimation library 'playeral' must have 'trackstemplate' animation")
	currentplayeranimation = templateanimation.duplicate()
	currentplayeranimationT0 = vd[NCONSTANTS.CFI_TIMESTAMP]
	currentplayeranimation.length = animationtimerunoff

	for i in range(currentplayeranimation.get_track_count()):
		currentplayeranimation.track_insert_key(i, 0, vd[NCONSTANTS.CFI_ANIMTRACKS + i])

	#var animname = "anim%d" % networkID
	var animname = "anim1"  # THIS CRASHES when 3 connections (2 animations same name)
	# See https://github.com/godotengine/godot/issues/98565

	currentplayeranimationlibrary.add_animation(animname, currentplayeranimation)
	PlayerAnimation.play("playeral/"+animname)
	PlayerAnimation.pause()
	PlayerAnimation.caches_cleared.connect(Dclearcachesig)
	PlayerAnimation.mixer_updated.connect(Dmixer_updated)

func startupremoteplayer(avatardata):
	get_parent().visible = false
	setupanimationtracks(avatardata["snapshottracks"])

func networkedavatarthinnedframedata(vd):
		# we could make this tolerate out of order values
	if logrecfile != null:
		logrecfile.store_var({"t":Time.get_ticks_msec()*0.001, "vd":vd})
	
	vd[NCONSTANTS.CFI_TIMESTAMP_RECIEVED] = Time.get_ticks_msec()*0.001
	var timestampoffset = vd[NCONSTANTS.CFI_TIMESTAMP_RECIEVED] - vd[NCONSTANTS.CFI_TIMESTAMP]
	if initialframestate == 0 or timestampoffset < mintimestampoffset:
		mintimestampoffset = timestampoffset
		print("new mintimeoffset ", timestampoffset)
		initialframestate = 1
	vd[NCONSTANTS.CFI_ARRIVALDELAY] = vd[NCONSTANTS.CFI_TIMESTAMP_RECIEVED] - mintimestampoffset - vd[NCONSTANTS.CFI_TIMESTAMPPREV]

	#assert (currentplayeranimation != null)
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

	if audiostreamopuschunked != null:
		var bufferlengthtime = audioserveroutputlatency + audiostreamopuschunked.queue_length_frames()*1.0/audiostreamopuschunked.audiosamplerate
		if bufferlengthtime < audiobufferregulationtime:
			if audiobufferpitchscale != 1.0:
				if bufferlengthtime < audiobufferregulationtimeLow:
					audiobufferpitchscale = 1.0
					get_parent().PF_setvoicespeedup(audiobufferpitchscale)
					print("SETTING audiobufferpitchscale ", audiobufferpitchscale)
		else:
			var w = inverse_lerp(audiobufferregulationtime, audioserveroutputlatency + audiobuffersize/audiostreamopuschunked.audiosamplerate, bufferlengthtime)
			audiobufferpitchscale = lerp(audiobufferregulationpitchlow, audiobufferregulationpitch, w)
			get_parent().PF_setvoicespeedup(audiobufferpitchscale)
			print("SETTING audiobufferpitchscale ", audiobufferpitchscale)

var audiostreamopuschunked : AudioStream = null
#var player_audiostreamplayer = null

func _ready():
	if get_parent().has_method("PF_playvoicestream"):
		get_parent().PF_playvoicestream()
		if get_parent().PF_getvoicestream() == null and ClassDB.can_instantiate("AudioStreamOpusChunked"):
			audiostreamopuschunked = ClassDB.instantiate("AudioStreamOpusChunked")
			get_parent().PF_setvoicestream(audiostreamopuschunked)
		if get_parent().PF_getvoicestream() != null and get_parent().PF_getvoicestream().is_class("AudioStreamOpusChunked"):
			audiostreamopuschunked = get_parent().PF_getvoicestream()
			setrecopusvalues(48000, 960)
		elif get_parent().PF_getvoicestream() != null:
			print("AudioStreamPlayer.stream must be type AudioStreamOpusChunked ", get_parent().PF_getvoicestream())
	else:
		print("Need an PF_playvoicestream for an AudioStreamPlayer node in RemotePlayer to do voip")


const asciiopenbrace = 123 # "{".to_ascii_buffer()[0]
const asciiclosebrace = 125 # "}".to_ascii_buffer()[0]
var lenchunkprefix = -1
var opusstreamcount = 0
var opusframecount = 0
const Noutoforderqueue = 4
const Npacketinitialbatching = 2
var outoforderchunkqueue = [ ]
var opusframequeuecount = 0
var audiobuffersize = 50*882

func setrecopusvalues(opussamplerate, opusframesize):
	var opusframeduration = opusframesize*1.0/opussamplerate
	audiostreamopuschunked.opusframesize = opusframesize
	audiostreamopuschunked.opussamplerate = opussamplerate
	audiostreamopuschunked.audiosamplerate = ProjectSettings.get_setting_with_override("audio/driver/mix_rate")  # AudioServer.get_mix_rate()
	audiostreamopuschunked.mix_rate = ProjectSettings.get_setting_with_override("audio/driver/mix_rate")  # AudioServer.get_mix_rate()
	audiostreamopuschunked.audiosamplesize = int(audiostreamopuschunked.audiosamplerate*opusframeduration)
	audiobuffersize = audiostreamopuschunked.audiosamplesize*audiostreamopuschunked.audiosamplechunks

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
			get_parent().PF_playvoicestream()
			if h.has("talkingtimestart"):
				if audiostreamopuschunked.opusframesize != h["opusframesize"] or \
						audiostreamopuschunked.opussamplerate != h["opussamplerate"]:
					setrecopusvalues(h["opussamplerate"], h["opusframesize"])
				lenchunkprefix = int(h["lenchunkprefix"])
				opusstreamcount = int(h["opusstreamcount"])
				opusframecount = 0
				if h.has("opusframecount"):
					print("Mid speech header!!! ", h["opusframecount"])
					opusframecount = h["opusframecount"]
				outoforderchunkqueue.clear()
				for i in range(Noutoforderqueue):
					outoforderchunkqueue.push_back(null)
				opusframequeuecount = 0
				assert (Npacketinitialbatching < Noutoforderqueue)
				audiostreamopuschunked.resetdecoder()
				
	elif lenchunkprefix == -1:
		pass

	elif lenchunkprefix == 0:
		audiostreamopuschunked.push_opus_packet(packet, lenchunkprefix, 0)
		
	elif packet[1]&128 == (opusstreamcount%2)*128:
		assert (lenchunkprefix == 2)
		var opusframecountI = packet[0] + (packet[1]&127)*256
		var opusframecountR = opusframecountI - opusframecount
		if opusframecountR < 0:
			print("framecount Wrapround 10mins? ", opusframecount, " ", opusframecountI)
			opusframecount = opusframecountI
			opusframecountR = 0
		if opusframecountR >= 0:
			while opusframecountR >= Noutoforderqueue:
				print("shifting outoforderqueue ", opusframecountR, " ", ("null" if outoforderchunkqueue[0] == null else len(outoforderchunkqueue[0])))
				if outoforderchunkqueue[0] != null:
					audiostreamopuschunked.push_opus_packet(outoforderchunkqueue[0], lenchunkprefix, 0)
					opusframequeuecount -= 1
				elif outoforderchunkqueue[1] != null:
					audiostreamopuschunked.push_opus_packet(outoforderchunkqueue[1], lenchunkprefix, 1)
				outoforderchunkqueue.pop_front()
				outoforderchunkqueue.push_back(null)
				opusframecountR -= 1
				opusframecount += 1
				assert (opusframequeuecount >= 0)
		
			if false and opusframecount != 0 and opusframequeuecount == 0:
				# optimize case to avoid using queue
				audiostreamopuschunked.push_opus_packet(packet, lenchunkprefix, 0)
				opusframecount += 1

			else:
				outoforderchunkqueue[opusframecountR] = packet
				opusframequeuecount += 1
				while outoforderchunkqueue[0] != null and opusframecount + opusframequeuecount >= Npacketinitialbatching:
					if not audiostreamopuschunked.chunk_space_available():
						print("!!! chunk space filled up")
						break
					audiostreamopuschunked.push_opus_packet(outoforderchunkqueue.pop_front(), lenchunkprefix, 0)
					outoforderchunkqueue.push_back(null)
					opusframecount += 1
					opusframequeuecount -= 1
					assert (opusframequeuecount >= 0)
			
	else:
		print("dropping frame with opusstream number mismatch")
