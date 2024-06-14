extends HBoxContainer

var audioopuschunkedeffect : AudioEffect = null
var chunkprefix : PackedByteArray = PackedByteArray([0,0]) 

func transmitaudiopacket(packet):
	var PlayerConnections = get_node("../../..")
	var PlayerFrame = PlayerConnections.LocalPlayer.get_node("PlayerFrame")
	if PlayerFrame.networkID >= 1:
		PlayerConnections.rpc("RPCincomingaudiopacket", packet)
	if PlayerFrame.doppelgangernode != null:
		var doppelnetoffset = PlayerFrame.NetworkGatewayForDoppelganger.get_node("DoppelgangerPanel").getnetoffset()
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
func _process(delta):
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
	elif not talking and currentlytalking:
		currentlytalking = false
		transmitaudiopacket(JSON.stringify({"opusframecount":opusframecount}).to_ascii_buffer())
		opusstreamcount += 1

	while audioopuschunkedeffect.chunk_available():
		var chunkmax = audioopuschunkedeffect.chunk_max()
		$ColorRectWitness.visible = (chunkmax != 0)
		$ColorRectWitness.size.y = min(size.y-2, chunkmax*30)+2
		if currentlytalking:
			chunkprefix.set(0, (opusframecount%256))  # 32768 frames is 10 minutes
			chunkprefix.set(1, (int(opusframecount/256)&127) + (opusstreamcount%2)*128)
			opusframecount += 1
			var opuspacket = audioopuschunkedeffect.pop_opus_packet(chunkprefix)
			transmitaudiopacket(opuspacket)
		else:
			audioopuschunkedeffect.drop_chunk()

func _ready():
	assert ($AudioStreamPlayerMicrophone.bus == "MicrophoneBus")
	assert ($AudioStreamPlayerMicrophone.stream.is_class("AudioStreamMicrophone"))
	var microphonebusidx = AudioServer.get_bus_index($AudioStreamPlayerMicrophone.bus)
	for i in range(AudioServer.get_bus_effect_count(microphonebusidx)):
		if AudioServer.get_bus_effect(microphonebusidx, i).is_class("AudioEffectOpusChunked"):
			audioopuschunkedeffect = AudioServer.get_bus_effect(microphonebusidx, i)
	if audioopuschunkedeffect == null and ClassDB.can_instantiate("AudioEffectOpusChunked"):
		audioopuschunkedeffect = AudioEffectOpusChunked.new()
		AudioServer.add_bus_effect(microphonebusidx, audioopuschunkedeffect)
	print("audioopuschunkedeffect ", audioopuschunkedeffect)
	
