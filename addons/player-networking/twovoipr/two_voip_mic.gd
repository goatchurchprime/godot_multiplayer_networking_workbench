extends Node

var audioopuschunkedeffect : AudioEffect = null
var microphonefeed = null
var audiostreamplayermicrophone : AudioStreamPlayer = null

var chunkprefix : PackedByteArray = PackedByteArray([0,0]) 

var leadtime : float = 0.15
var hangtime : float  = 1.2
var voxthreshhold = 0.2
var speakingvolume = 0.0

var currentlytalking = false
var opusframecount = 0
var opusstreamcount = 0

var hangframes = 25
var hangframescountup = 0
var chunkmaxpersist = 0.0

var audiosampleframetextureimage : Image
var audiosampleframetexture : ImageTexture
var audiosampleframematerial = null

signal transmitaudiopacket(opuspacket, opusframecount)
signal transmitaudiojsonpacket(audiostreampacketheader)
signal micaudiowarnings(name, value)

var voxenabled = false
var denoiseenabled = false
var pttpressed = false
var micnotplayingwarning = false

const rootmeansquaremaxmeasurement = false

var microphoneaudiosamplescountSeconds = 0.0
var microphoneaudiosamplescount = 0
var microphoneaudiosamplescountSecondsSampleWindow = 10.0

var talkingtimestart = 0

func setopusvalues(opussamplerate, opusframedurationms, opusbitrate, opuscomplexity, opusoptimizeforvoice):
	assert (not currentlytalking)
	audioopuschunkedeffect.opussamplerate = opussamplerate
	audioopuschunkedeffect.opusframesize = int(opussamplerate*opusframedurationms/1000.0)
	audioopuschunkedeffect.opusbitrate = opusbitrate
	audioopuschunkedeffect.opuscomplexity = opuscomplexity
	audioopuschunkedeffect.opusoptimizeforvoice = opusoptimizeforvoice

	audioopuschunkedeffect.audiosamplerate = AudioServer.get_mix_rate()
	audioopuschunkedeffect.audiosamplesize = int(audioopuschunkedeffect.audiosamplerate*opusframedurationms/1000.0)

	var audiosampleframedata = PackedVector2Array()
	audiosampleframedata.resize(audioopuschunkedeffect.audiosamplesize)
	for j in range(audioopuschunkedeffect.audiosamplesize):
		audiosampleframedata.set(j, Vector2(-0.5,0.9) if (j%10)<5 else Vector2(0.6,0.1))
	audiosampleframetextureimage = Image.create_from_data(audioopuschunkedeffect.audiosamplesize, 1, false, Image.FORMAT_RGF, audiosampleframedata.to_byte_array())
	audiosampleframetexture = ImageTexture.create_from_image(audiosampleframetextureimage)
	audiosampleframematerial.set_shader_parameter("chunktexture", audiosampleframetexture)
	#audiostreamplayermicrophone.finished.connect(func a(): audiostreamplayermicrophone.playing = true)

func _ready():
	if OS.get_name() == "Android" and not OS.request_permission("android.permission.RECORD_AUDIO"):
		print("Waiting for user response after requesting audio permissions")
		# you also need to enabled Record Audio in the android export settings
		@warning_ignore("untyped_declaration")
		var x = await get_tree().on_request_permissions_result
		var permission : String = x[0]
		var granted : bool = x[1]
		assert (permission == "android.permission.RECORD_AUDIO")
		print("Audio permission granted ", granted)

	if not ClassDB.can_instantiate("AudioEffectOpusChunked"):
		micnotplayingwarning = true
		micaudiowarnings.emit("MicNotPlayingWarning", micnotplayingwarning)
		return

	if Engine.has_singleton("MicrophoneServer"):
		print("Using MicrophoneServer post PR#108773")  # https://github.com/godotengine/godot/pull/108773
		microphonefeed = Engine.get_singleton("MicrophoneServer").get_feed(0)
		microphonefeed.set_active(true)
		micaudiowarnings.emit("MicStreamPlayerNotice", true)
		audioopuschunkedeffect = ClassDB.instantiate("AudioEffectOpusChunked")
	
	else:
		print("Creating Microphone Stream, Player and Bus")
		assert (AudioServer.get_bus_index("MicrophoneBus") == -1)
		AudioServer.add_bus()
		var microphonebusidx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(microphonebusidx, "MicrophoneBus")
		AudioServer.set_bus_mute(microphonebusidx, true)
		audioopuschunkedeffect = ClassDB.instantiate("AudioEffectOpusChunked")
		AudioServer.add_bus_effect(microphonebusidx, audioopuschunkedeffect)

		audiostreamplayermicrophone = AudioStreamPlayer.new()
		audiostreamplayermicrophone.name = "AudioStreamPlayerMicrophone"
		add_child(audiostreamplayermicrophone)
		audiostreamplayermicrophone.bus = "MicrophoneBus"
		audiostreamplayermicrophone.stream = AudioStreamMicrophone.new()
		#await get_tree().create_timer(2.0).timeout
		audiostreamplayermicrophone.play()

func processtalkstreamends():
	var talking = pttpressed
	if talking and not currentlytalking:
		var frametimesecs = audioopuschunkedeffect.opusframesize*1.0/audioopuschunkedeffect.opussamplerate
		talkingtimestart = Time.get_ticks_msec()*0.001
		var leadframes = leadtime/frametimesecs
		hangframes = hangtime/frametimesecs
		while leadframes > 0.0 and audioopuschunkedeffect.undrop_chunk():
			leadframes -= 1
			talkingtimestart -= frametimesecs
		var audiostreampacketheader = { 
			"opusframesize":audioopuschunkedeffect.opusframesize, 
			"opussamplerate":audioopuschunkedeffect.opussamplerate, 
			"lenchunkprefix":len(chunkprefix), 
			"opusstreamcount":opusstreamcount, 
			"talkingtimestart":talkingtimestart 
		}
		audioopuschunkedeffect.resetencoder(false)
		transmitaudiojsonpacket.emit(audiostreampacketheader)
		get_parent().PlayerConnections.peerconnections_possiblymissingaudioheaders.clear()
		opusframecount = 0
		currentlytalking = true
		if microphonefeed == null and not audiostreamplayermicrophone.playing:
			audiostreamplayermicrophone.playing = true
			print("Set microphone playing again (switched off by system)")

	elif not talking and currentlytalking:
		currentlytalking = false
		var talkingtimeend = Time.get_ticks_msec()*0.001
		var talkingtimeduration = talkingtimeend - talkingtimestart
		var audiopacketstreamfooter = {
			"opusstreamcount":opusstreamcount, 
			"opusframecount":opusframecount,
			"talkingtimeduration":talkingtimeduration,
			"talkingtimeend":talkingtimeend 
		}
		print("My voice chunktime=", talkingtimeduration/opusframecount, " over ", talkingtimeduration, " seconds")
		transmitaudiojsonpacket.emit(audiopacketstreamfooter)
		opusstreamcount += 1

func processvox():
	if denoiseenabled:
		audioopuschunkedeffect.denoise_resampled_chunk()
	var chunkmax = audioopuschunkedeffect.chunk_max(rootmeansquaremaxmeasurement, denoiseenabled)
	audiosampleframematerial.set_shader_parameter("chunkmax", chunkmax)
	if chunkmax >= voxthreshhold:
		if voxenabled and not pttpressed:
			pttpressed = true
		hangframescountup = 0
		if chunkmax > chunkmaxpersist:
			chunkmaxpersist = chunkmax
			print("chunkmaxpersist ", chunkmaxpersist)
			audiosampleframematerial.set_shader_parameter("chunkmaxpersist", chunkmaxpersist)
	else:
		if hangframescountup == hangframes:
			if voxenabled:
				pttpressed = false
			chunkmaxpersist = 0.0
			audiosampleframematerial.set_shader_parameter("chunkmaxpersist", chunkmaxpersist)
		hangframescountup += 1

	if pttpressed:
		audiosampleframematerial.set_shader_parameter("chunktexenabled", true)
		var audiosamples = audioopuschunkedeffect.read_chunk(false)
		audiosampleframetextureimage.set_data(audioopuschunkedeffect.audiosamplesize, 1, false, Image.FORMAT_RGF, audiosamples.to_byte_array())
		audiosampleframetexture.update(audiosampleframetextureimage)
		return chunkmax

	else:
		audiosampleframematerial.set_shader_parameter("chunktexenabled", false)
		return 0.0

func processsendopuschunk():
	if currentlytalking:
		if len(chunkprefix) == 2:
			chunkprefix.set(0, (opusframecount%256))  # 32768 frames is 10 minutes
			chunkprefix.set(1, (int(opusframecount/256)&127) + (opusstreamcount%2)*128)
		else:
			assert (len(chunkprefix) == 0)
		if denoiseenabled:
			audioopuschunkedeffect.denoise_resampled_chunk()
		var opuspacket = audioopuschunkedeffect.read_opus_packet(chunkprefix)
		transmitaudiopacket.emit(opuspacket, opusframecount)
		opusframecount += 1
	audioopuschunkedeffect.drop_chunk()

func _process(delta):
	if microphonefeed != null and microphonefeed.is_active():
		while true:
			var microphonesamples = microphonefeed.get_frames(audioopuschunkedeffect.audiosamplesize)
			if len(microphonesamples) != 0:
				audioopuschunkedeffect.push_chunk(microphonesamples)
				microphoneaudiosamplescount += len(microphonesamples)
			else:
				break
		microphoneaudiosamplescountSeconds += delta
		if microphoneaudiosamplescountSeconds > microphoneaudiosamplescountSecondsSampleWindow:
			print("measured mic audiosamples rate ", microphoneaudiosamplescount/microphoneaudiosamplescountSeconds)
			microphoneaudiosamplescount = 0
			microphoneaudiosamplescountSeconds = 0.0
			microphoneaudiosamplescountSecondsSampleWindow *= 1.5

	if audioopuschunkedeffect != null:
		processtalkstreamends()
		while audioopuschunkedeffect.chunk_available():
			speakingvolume = processvox()
			processtalkstreamends()
			processsendopuschunk()

	var lmicnotplayingwarning = (not microphonefeed.is_active() if microphonefeed else not audiostreamplayermicrophone.playing)
	if micnotplayingwarning != lmicnotplayingwarning:
		micnotplayingwarning = lmicnotplayingwarning
		micaudiowarnings.emit("MicNotPlayingWarning", micnotplayingwarning)
