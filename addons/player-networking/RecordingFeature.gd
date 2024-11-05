extends HBoxContainer

var audioopuschunkedeffect : AudioEffect = null

var chunkprefix : PackedByteArray = PackedByteArray([0,0]) 
#var chunkprefix : PackedByteArray = PackedByteArray() 

@onready var PlayerConnections = find_parent("PlayerConnections")
# Opus compression settings
var opussamplerate_default = 48000 # 8, 12, 16, 24, 48 KHz
var opusframedurationms_default = 20 # 2.5, 5, 10, 20 40, 60
var opusbitrate_default = 10000  # 3000, 6000, 10000, 12000, 24000
var opuscomplexity_default = 5 # 0-10
var opusoptimizeforvoice_default = true

var leadtime : float = 0.1
var hangtime : float  = 1.2
var voxthreshhold = 0.2

var currentlytalking = false
var opusframecount = 0
var opusstreamcount = 0

var hangframes = 25
var hangframescountup = 0
var chunkmaxpersist = 0.0

var audiosampleframetextureimage : Image
var audiosampleframetexture : ImageTexture

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
	$VoxThreshold.material.set_shader_parameter("chunktexture", audiosampleframetexture)
	#$AudioStreamPlayerMicrophone.finished.connect(func a(): $AudioStreamPlayerMicrophone.playing = true)

var talkingtimestart = 0
func processtalkstreamends():
	var talking = $PTT.button_pressed
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
		audioopuschunkedeffect.flush_opus_encoder(false)
		PlayerConnections.LocalPlayerFrame.transmitaudiopacket(JSON.stringify(audiostreampacketheader).to_ascii_buffer())
		PlayerConnections.peerconnections_possiblymissingaudioheaders.clear()
		opusframecount = 0
		currentlytalking = true
		if $AudioStreamPlayerMicrophone.playing != true:
			$AudioStreamPlayerMicrophone.playing = true
			print("Set microphone playing again (switched off by system)")

	elif not talking and currentlytalking:
		currentlytalking = false
		var PlayerFrame = PlayerConnections.LocalPlayer.get_node("PlayerFrame")
		var talkingtimeend = Time.get_ticks_msec()*0.001
		var audiopacketstreamfooter = {
			"opusstreamcount":opusstreamcount, 
			"opusframecount":opusframecount,
			"talkingtimeduration":talkingtimeend - talkingtimestart,
			"talkingtimeend":talkingtimeend 
		}
		PlayerFrame.transmitaudiopacket(JSON.stringify(audiopacketstreamfooter).to_ascii_buffer())
		opusstreamcount += 1

	elif talking and PlayerConnections.peerconnections_possiblymissingaudioheaders:
		var audiostreampacketheadermiddle = { 
			"opusframesize":audioopuschunkedeffect.opusframesize, 
			"opussamplerate":audioopuschunkedeffect.opussamplerate, 
			"lenchunkprefix":len(chunkprefix), 
			"opusstreamcount":opusstreamcount, 
			"talkingtimestart":talkingtimestart, 
			"opusframecount":opusframecount
		}
		for id in PlayerConnections.peerconnections_possiblymissingaudioheaders:
			PlayerConnections.rpc_id(id, "RPC_incomingaudiopacket", JSON.stringify(audiostreampacketheadermiddle).to_ascii_buffer())
		PlayerConnections.peerconnections_possiblymissingaudioheaders.clear()


func processvox():
	if $Denoise.button_pressed:
		audioopuschunkedeffect.denoise_resampled_chunk()
	var chunkmax = audioopuschunkedeffect.chunk_max(false, $Denoise.button_pressed)
	$VoxThreshold.material.set_shader_parameter("chunkmax", chunkmax)
	if chunkmax >= voxthreshhold:
		if $Vox.button_pressed and not $PTT.button_pressed:
			$PTT.set_pressed(true)
		hangframescountup = 0
		if chunkmax > chunkmaxpersist:
			chunkmaxpersist = chunkmax
			$VoxThreshold.material.set_shader_parameter("chunkmaxpersist", chunkmaxpersist)
	else:
		if hangframescountup == hangframes:
			if $Vox.button_pressed:
				$PTT.set_pressed(false)
			chunkmaxpersist = 0.0
			$VoxThreshold.material.set_shader_parameter("chunkmaxpersist", chunkmaxpersist)
		hangframescountup += 1

	if $PTT.button_pressed:
		$VoxThreshold.material.set_shader_parameter("chunktexenabled", true)
		var audiosamples = audioopuschunkedeffect.read_chunk(false)
		audiosampleframetextureimage.set_data(audioopuschunkedeffect.audiosamplesize, 1, false, Image.FORMAT_RGF, audiosamples.to_byte_array())
		audiosampleframetexture.update(audiosampleframetextureimage)
		return chunkmax

	else:
		$VoxThreshold.material.set_shader_parameter("chunktexenabled", false)
		return 0.0
		
func processsendopuschunk():
	if currentlytalking:
		if len(chunkprefix) == 2:
			chunkprefix.set(0, (opusframecount%256))  # 32768 frames is 10 minutes
			chunkprefix.set(1, (int(opusframecount/256)&127) + (opusstreamcount%2)*128)
		else:
			assert (len(chunkprefix) == 0)
		opusframecount += 1
		if $Denoise.button_pressed:
			audioopuschunkedeffect.denoise_resampled_chunk()
		var opuspacket = audioopuschunkedeffect.read_opus_packet(chunkprefix)
		PlayerConnections.LocalPlayerFrame.transmitaudiopacket(opuspacket)
	audioopuschunkedeffect.drop_chunk()

func _process(delta):
	if audioopuschunkedeffect != null:
		processtalkstreamends()
		while audioopuschunkedeffect.chunk_available():
			var speakingvolume = processvox()
			processsendopuschunk()
			PlayerConnections.LocalPlayer.PF_setspeakingvolume(speakingvolume if currentlytalking else 0.0)
	$MicNotPlayingWarning.visible = not $AudioStreamPlayerMicrophone.playing

func _ready():
	$VoxThreshold.material.set_shader_parameter("voxthreshhold", voxthreshhold)
	if $AudioStreamPlayerMicrophone.bus != "MicrophoneBus":
		printerr("AudioStreamPlayerMicrophone doesn't use bus called MicrophoneBus, disabling")
		$AudioStreamPlayerMicrophone.stop()
		return
	assert ($AudioStreamPlayerMicrophone.stream.is_class("AudioStreamMicrophone"))
	var microphonebusidx = AudioServer.get_bus_index($AudioStreamPlayerMicrophone.bus)
	for i in range(AudioServer.get_bus_effect_count(microphonebusidx)):
		if AudioServer.get_bus_effect(microphonebusidx, i).is_class("AudioEffectOpusChunked"):
			audioopuschunkedeffect = AudioServer.get_bus_effect(microphonebusidx, i)
	if audioopuschunkedeffect == null and ClassDB.can_instantiate("AudioEffectOpusChunked"):
		audioopuschunkedeffect = ClassDB.instantiate("AudioEffectOpusChunked")
		AudioServer.add_bus_effect(microphonebusidx, audioopuschunkedeffect)
	if audioopuschunkedeffect != null:
		setopusvalues(opussamplerate_default, opusframedurationms_default, opusbitrate_default, opuscomplexity_default, opusoptimizeforvoice_default)
	else:
		printerr("Unabled to find or instantiate AudioEffectOpusChunked on MicrophoneBus")
		$OpusWarningLabel.visible = true

func _on_vox_toggled(toggled_on):
	$PTT.toggle_mode = toggled_on

func _on_vox_threshold_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		voxthreshhold = event.position.x/$VoxThreshold.size.x
		$VoxThreshold.material.set_shader_parameter("voxthreshhold", voxthreshhold)

func _on_audio_stream_player_microphone_finished():
	print("*** _on_audio_stream_player_microphone_finished")
	$MicFinishedWarning.visible = true
