extends HBoxContainer

var audioopuschunkedeffect : AudioEffect = null
var chunkprefix : PackedByteArray = PackedByteArray([0,0]) 

@onready var PlayerConnections = find_parent("PlayerConnections")



var currentlytalking = false
var opusframecount = 0
var opusstreamcount = 0
var voxthreshhold = 0.2
var samplescountdown = 0
var samplesrunon = 25
var chunkmaxpersist = 0.0

var audiosampleframetextureimage : Image
var audiosampleframetexture : ImageTexture

func setupaudioshader():
	var audiosampleframedata = PackedVector2Array()
	audiosampleframedata.resize(audioopuschunkedeffect.audiosamplesize)
	for j in range(audioopuschunkedeffect.audiosamplesize):
		audiosampleframedata.set(j, Vector2(-0.5,0.9) if (j%10)<5 else Vector2(0.6,0.1))
	audiosampleframetextureimage = Image.create_from_data(audioopuschunkedeffect.audiosamplesize, 1, false, Image.FORMAT_RGF, audiosampleframedata.to_byte_array())
	audiosampleframetexture = ImageTexture.create_from_image(audiosampleframetextureimage)
	$VoxThreshold.material.set_shader_parameter("chunktexture", audiosampleframetexture)

func processtalkstreamends():
	var talking = $PTT.button_pressed
	if talking and not currentlytalking:
		var audiopacketheader = { "opusframesize":audioopuschunkedeffect.opusframesize, 
								  "audiosamplesize":audioopuschunkedeffect.audiosamplesize, 
								  "opussamplerate":audioopuschunkedeffect.opussamplerate, 
								  "audiosamplerate":audioopuschunkedeffect.audiosamplerate, 
								  "lenchunkprefix":len(chunkprefix), 
								  "opusstreamcount":opusstreamcount }
		var PlayerFrame = PlayerConnections.LocalPlayer.get_node("PlayerFrame")
		PlayerFrame.transmitaudiopacket(JSON.stringify(audiopacketheader).to_ascii_buffer())
		opusframecount = 0
		currentlytalking = true
		if $AudioStreamPlayerMicrophone.playing != true:
			$AudioStreamPlayerMicrophone.playing = true
			print("Set microphone playing again (switched off by system)")
	elif not talking and currentlytalking:
		currentlytalking = false
		var PlayerFrame = PlayerConnections.LocalPlayer.get_node("PlayerFrame")
		PlayerFrame.transmitaudiopacket(JSON.stringify({"opusframecount":opusframecount}).to_ascii_buffer())
		opusstreamcount += 1

func processvox():
	if $Denoise.button_pressed:
		audioopuschunkedeffect.denoise_resampled_chunk()
	var chunkmax = audioopuschunkedeffect.chunk_max(false, $Denoise.button_pressed)
	$VoxThreshold.material.set_shader_parameter("chunkmax", chunkmax)
	if chunkmax >= voxthreshhold:
		if $Vox.button_pressed and not $PTT.button_pressed:
			$PTT.set_pressed(true)
		samplescountdown = samplesrunon
		if chunkmax > chunkmaxpersist:
			chunkmaxpersist = chunkmax
			$VoxThreshold.material.set_shader_parameter("chunkmaxpersist", chunkmaxpersist)
	elif samplescountdown > 0:
		samplescountdown -= 1
		if samplescountdown == 0:
			if $Vox.button_pressed:
				$PTT.set_pressed(false)
			chunkmaxpersist = 0.0
			$VoxThreshold.material.set_shader_parameter("chunkmaxpersist", chunkmaxpersist)

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
		chunkprefix.set(0, (opusframecount%256))  # 32768 frames is 10 minutes
		chunkprefix.set(1, (int(opusframecount/256)&127) + (opusstreamcount%2)*128)
		opusframecount += 1
		if $Denoise.button_pressed:
			audioopuschunkedeffect.denoise_resampled_chunk()
		var opuspacket = audioopuschunkedeffect.read_opus_packet(chunkprefix)
		var PlayerFrame = PlayerConnections.LocalPlayer.get_node("PlayerFrame")
		PlayerFrame.transmitaudiopacket(opuspacket)
	audioopuschunkedeffect.drop_chunk()

func _process(delta):
	if audioopuschunkedeffect != null:
		processtalkstreamends()
		while audioopuschunkedeffect.chunk_available():
			var speakingvolume = processvox()
			PlayerConnections.LocalPlayer.PF_setspeakingvolume(speakingvolume)
			processsendopuschunk()

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
		setupaudioshader()
	else:
		printerr("Unabled to find or instantiate AudioEffectOpusChunked on MicrophoneBus")
	
func _on_vox_toggled(toggled_on):
	$PTT.toggle_mode = toggled_on

func _on_vox_threshold_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		voxthreshhold = event.position.x/$VoxThreshold.size.x
		$VoxThreshold.material.set_shader_parameter("voxthreshhold", voxthreshhold)
