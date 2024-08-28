extends HBoxContainer

var audioopuschunkedeffect : AudioEffect = null
var chunkprefix : PackedByteArray = PackedByteArray([0,0]) 

@onready var PlayerConnections = find_parent("PlayerConnections")

func transmitaudiopacket(packet):
	var PlayerFrame = PlayerConnections.LocalPlayer.get_node("PlayerFrame")
	if PlayerFrame.networkID >= 1:
		PlayerConnections.rpc("RPCincomingaudiopacket", packet)
	if PlayerFrame.doppelgangernode != null:
		var doppelnetoffset = PlayerFrame.NetworkGatewayForDoppelganger.DoppelgangerPanel.getnetoffset()
		var doppelgangerdelay = PlayerFrame.NetworkGatewayForDoppelganger.getrandomdoppelgangerdelay()
		if doppelgangerdelay != -1.0:
			await get_tree().create_timer(doppelgangerdelay*0.001).timeout
			if PlayerFrame.doppelgangernode != null:
				PlayerFrame.doppelgangernode.get_node("PlayerFrame").incomingaudiopacket(packet)
		else:
			print("dropaudframe")


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
		transmitaudiopacket(JSON.stringify(audiopacketheader).to_ascii_buffer())
		opusframecount = 0
		currentlytalking = true
		if $AudioStreamPlayerMicrophone.playing != true:
			$AudioStreamPlayerMicrophone.playing = true
			print("Set microphone playing again (switched off by system)")
	elif not talking and currentlytalking:
		currentlytalking = false
		transmitaudiopacket(JSON.stringify({"opusframecount":opusframecount}).to_ascii_buffer())
		opusstreamcount += 1

func processvox():
	var chunkmax = audioopuschunkedeffect.chunk_max(false, false)
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
	else:
		$VoxThreshold.material.set_shader_parameter("chunktexenabled", false)
	
func processsendopuschunk():
	if currentlytalking:
		chunkprefix.set(0, (opusframecount%256))  # 32768 frames is 10 minutes
		chunkprefix.set(1, (int(opusframecount/256)&127) + (opusstreamcount%2)*128)
		opusframecount += 1
		if $Denoise.button_pressed:
			audioopuschunkedeffect.denoise_resampled_chunk()
		var opuspacket = audioopuschunkedeffect.read_opus_packet(chunkprefix)
		transmitaudiopacket(opuspacket)
	audioopuschunkedeffect.drop_chunk()

func _process(delta):
	if audioopuschunkedeffect != null:
		processtalkstreamends()
		while audioopuschunkedeffect.chunk_available():
			processvox()
			processsendopuschunk()

func _ready():
	$VoxThreshold.material.set_shader_parameter("voxthreshhold", voxthreshhold)
	assert ($AudioStreamPlayerMicrophone.bus == "MicrophoneBus")
	assert ($AudioStreamPlayerMicrophone.stream.is_class("AudioStreamMicrophone"))
	var microphonebusidx = AudioServer.get_bus_index($AudioStreamPlayerMicrophone.bus)
	for i in range(AudioServer.get_bus_effect_count(microphonebusidx)):
		if AudioServer.get_bus_effect(microphonebusidx, i).is_class("AudioEffectOpusChunked"):
			audioopuschunkedeffect = AudioServer.get_bus_effect(microphonebusidx, i)
	if audioopuschunkedeffect == null and ClassDB.can_instantiate("AudioEffectOpusChunked"):
		audioopuschunkedeffect = ClassDB.instantiate("AudioEffectOpusChunked")
		AudioServer.add_bus_effect(microphonebusidx, audioopuschunkedeffect)
	print("audioopuschunkedeffect ", audioopuschunkedeffect)
	if audioopuschunkedeffect != null:
		setupaudioshader()
	
func _on_vox_toggled(toggled_on):
	$PTT.toggle_mode = toggled_on

func _on_vox_threshold_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		voxthreshhold = event.position.x/$VoxThreshold.size.x
		$VoxThreshold.material.set_shader_parameter("voxthreshhold", voxthreshhold)
