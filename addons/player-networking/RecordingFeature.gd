extends HBoxContainer

var Ddisablevoip = false
var Dstorespeechfilename = "user://welcomespeech.dat"
var welcomespeechfilename = "res://addons/player-networking/welcomespeech.dat"

var micrecordingdata = null
const max_recording_seconds = 5.0

var recordingnumberC = 1
var audiocaptureeffect = null

var spectrumanalyzereffect = null

var voipcapturepackets = null
var voipcapturesize = 0


#GODOT_SAMPLE_RATE = 44100;
#OPUS_FRAME_SIZE = 480;  10ms
#OPUS_SAMPLE_RATE = 48000;
#godot_frame_size = 441 = OPUS_FRAME_SIZE * GODOT_SAMPLE_RATE / OPUS_SAMPLE_RATE = 


var packetgaps = [ ]
var testpacketnumber = 0
var packettime = 0

var recordingstart_msticks = 0
var currentlyrecording = false

var voipcapturepacketsplayback = null
var voipcapturepacketsplaybackIndex = 0
var voipcapturepacketsplaybackstart_msticks = 0
var voipcapturepacketsplayback_msduration = 1

var captureeffectpacketsplayback = null
var captureeffectpacketsplaybackIndex = 0


var Donceaudio = true
func _physics_process(delta):
	if not audiostreamrecorder.playing and Donceaudio:
		print("-- Rec notEEEE playiEEEEEEEEEEEEEEEEE1ng ", Time.get_ticks_msec()/1000.0)
		Donceaudio = false
	elif audiostreamrecorder.playing and not Donceaudio:
		print("-- Rec back to true ")
		Donceaudio = true
		#var p = audiostreamrecorder.get_parent()
		#p.remove_child(audiostreamrecorder)
		#p.add_child(audiostreamrecorder)
	
	#if audiostreamrecorder.playing and spectrumanalyzereffect:
	#	print(spectrumanalyzereffect.get_magnitude_for_frequency_range(100,200))

var playbackthing = null
# steal the viseme code from https://github.com/Malcolmnixon/godot-lip-sync/blob/main/addons/godot-lip-sync/lip_sync.gd

var Dcaptureeffectinsteadofrecording = true
var captureeffectpackets = null

func _process(delta):
	if not audiostreamrecorder.playing and Donceaudio:
		print("s-- Rec not playing")
		Donceaudio = false
		
	while audiocaptureeffect.get_frames_available() >= 441:
		var samples = audiocaptureeffect.get_buffer(441)
		if handyopusnodeencoder:   # keep flushing it through
			var packet = handyopusnodeencoder.encode_opus_packet(samples)
			if voipcapturepackets != null:
				voipcapturepackets.append(packet)
				voipcapturesize += len(packet)
				var Npackettime = Time.get_ticks_usec()
				#packetgaps.append(Npackettime - packettime)
				packetgaps.append(testpacketnumber)
				packettime = Npackettime
				print("lvoip_packet_ready ", testpacketnumber)		

		if captureeffectpackets != null:
			captureeffectpackets.append(samples)
		testpacketnumber += 1
		
	if currentlyrecording:
		if (Time.get_ticks_msec() - recordingstart_msticks)/1000 > max_recording_seconds:
			stop_recording()

	if captureeffectpacketsplayback != null:
		while playbackthing.get_frames_available() > 441 and captureeffectpacketsplaybackIndex < len(captureeffectpacketsplayback):
			playbackthing.push_buffer(captureeffectpacketsplayback[captureeffectpacketsplaybackIndex])
			captureeffectpacketsplaybackIndex += 1
			print(" cplaybackthing ", captureeffectpacketsplaybackIndex, " ", playbackthing.get_frames_available())

	if voipcapturepacketsplayback != null:
		if playbackthing:
			while playbackthing.get_frames_available() > 441 and voipcapturepacketsplaybackIndex < len(voipcapturepacketsplayback):
				#var frames = staticvoipaudiostream.spush_packet(voipcapturepacketsplayback[voipcapturepacketsplaybackIndex])
				var frames = handyopusnode.decode_opus_packet(voipcapturepacketsplayback[voipcapturepacketsplaybackIndex])

				playbackthing.push_buffer(frames)
				voipcapturepacketsplaybackIndex += 1
				print(" playbackthing ", len(frames))
		else:
			var currentplaybackduration = Time.get_ticks_msec() - voipcapturepacketsplaybackstart_msticks
			var packetproportion = currentplaybackduration / voipcapturepacketsplayback_msduration
			var targetvoipcapturepacketsplaybackIndex = packetproportion*len(voipcapturepacketsplayback) + 20
			while voipcapturepacketsplaybackIndex < targetvoipcapturepacketsplaybackIndex and voipcapturepacketsplaybackIndex < len(voipcapturepacketsplayback):
				$PlayRecord/AudioStreamPlayer.stream.push_packet(voipcapturepacketsplayback[voipcapturepacketsplaybackIndex])
				voipcapturepacketsplaybackIndex += 1

			if currentplaybackduration > voipcapturepacketsplayback_msduration + 500:
				voipcapturepacketsplayback = null
				$PlayRecord/AudioStreamPlayer.stovoipinputcapturep()
				$PlayRecord/AudioStreamPlayer.stream = null

func start_recording():
	print("start_recording")
	currentlyrecording = true
	recordingstart_msticks = Time.get_ticks_msec()
	if not audiostreamrecorder.playing:
		print("MicRecord/AudioStreamRecorder not playing (autoplay setting failed), trying to set now")
		audiostreamrecorder.playing = true
	if $VoipMode.button_pressed:
		voipcapturepackets = [ ]
		voipcapturesize = 0
		packetgaps = [ ]
		testpacketnumber = 0
	else:
		captureeffectpackets = [ ]

func stop_recording():
	print("stop_recording")
	currentlyrecording = false
	var recording_duration = (Time.get_ticks_msec() - recordingstart_msticks)/1000.0 + 0.01
	var underlyingbytessize = 0
	if captureeffectpackets != null:
		micrecordingdata = { "captureeffectpackets":captureeffectpackets, 
							 "duration":recording_duration }
		underlyingbytessize = len(captureeffectpackets)*len(captureeffectpackets[0])
		captureeffectpackets = null
		
	elif voipcapturepackets != null:
		micrecordingdata = { "voipcapturepackets":voipcapturepackets, 
							 "duration":recording_duration }
		underlyingbytessize = voipcapturesize
		#for p in voipcapturepackets:
		#	print(p,",")
		voipcapturepackets = null
		print(packetgaps)
	print("created data bytes ", len(var_to_bytes(micrecordingdata)), " underlying ", underlyingbytessize)
	$RecordSize.text = "l-"+str(underlyingbytessize)

		

var audiostreamrecorder = null

var handyopusnode = null
var handyopusnodeencoder = null
var handyopusnodeencoder2 = null

func _ready():
	if ClassDB.can_instantiate("HandyOpusNode"):
		handyopusnode = ClassDB.instantiate("HandyOpusNode")#
		handyopusnodeencoder = ClassDB.instantiate("HandyOpusNode")
		#handyopusnodeencoder2 = ClassDB.instantiate("HandyOpusNode") 
		handyopusnodeencoder2 = ClassDB.instantiate("HandyOpusNode")
		print("Instantiated ", handyopusnode, handyopusnode.has_method("decode_opus_packet"))

	if Ddisablevoip:
		set_process(false)  
		$MicRecord.disabled = true
		return

	var fin = FileAccess.open(welcomespeechfilename, FileAccess.READ)
	if fin:
		micrecordingdata = fin.get_var()
		fin.close()

	# Build the AudioStreamMicrophone in top level in case there's a problem putting it in a Viewport
	audiostreamrecorder = get_node_or_null("/root/Main/AudioStreamRecorder")
	if audiostreamrecorder == null:
		audiostreamrecorder = get_node_or_null("MicRecord/AudioStreamRecorder")
	if audiostreamrecorder == null:
		audiostreamrecorder = AudioStreamPlayer.new()
		audiostreamrecorder.set_name("AudioStreamRecorder")
		#audiostreamrecorder.autoplay = true   # delay due to bad buffer linking if done on startup
		audiostreamrecorder.stream = AudioStreamMicrophone.new()
		audiostreamrecorder.bus = "Recorder"
		get_node("/root").add_child.call_deferred(audiostreamrecorder)
	else:
		assert (audiostreamrecorder.stream.is_class("AudioStreamMicrophone"))
		assert (audiostreamrecorder.bus == "Recorder")
		print("AudioStreamRecord playing: ", audiostreamrecorder.playing)
	
	var recordbus_idx = AudioServer.get_bus_index("Recorder")
	#assert (AudioServer.is_bus_mute(recordbus_idx) == true)
	spectrumanalyzereffect = AudioServer.get_bus_effect_instance(recordbus_idx, 1)
	print(spectrumanalyzereffect)
	audiocaptureeffect = AudioServer.get_bus_effect(recordbus_idx, 2)
	assert (audiocaptureeffect.is_class("AudioEffectCapture"))

	# upgrade to OneVoip system if addon from https://github.com/RevoluPowered/one-voip-godot-4/ detected
	# The VOIPInputCapture taps off the stream leaving it the same, but feeds it to the Recorder
	if true:
		$VoipMode.button_pressed = true
	else:
		$VoipMode.disabled = true

	#await get_tree().create_timer(5.5).timeout
	#print("Setting audiostreamrecorder to playing now")
	#audiostreamrecorder.playing = true

func _on_MicRecord_button_down():
	print("_on_MicRecord_button_down")
	if not currentlyrecording:
		start_recording()

func _on_MicRecord_button_up():
	print("_on_MicRecord_button_upE")
	if currentlyrecording:
		await get_tree().create_timer(0.25).timeout  # the mic lags so there's always a cutout
		stop_recording()

@rpc("any_peer") func remotesetmicrecord(lmicrecordingdata):
	micrecordingdata = lmicrecordingdata
	var r = micrecordingdata.get("voipcapturepackets", 0)
	if micrecordingdata.has("captureeffectpackets"):
		r = micrecordingdata["captureeffectpackets"]
	$RecordSize.text = "r-"+str(r)
	

func Dtoggleopuspackets():
	if micrecordingdata.has("captureeffectpackets"):
		micrecordingdata["voipcapturepackets"] = [ ]
		var l = 0
		for samples in micrecordingdata["captureeffectpackets"]:
			#var packet = handyopusnodeencoder2.encode_opus_packet(samples)
			#var packet = voipinputcapture.encode_opus_packet(samples)
			var packet = handyopusnodeencoder2.encode_opus_packet(samples)
			l += len(packet)
			micrecordingdata["voipcapturepackets"].append(packet)
		micrecordingdata.erase("captureeffectpackets")
		print("Converted to opus ", l)
	elif micrecordingdata.has("voipcapturepackets"):
		micrecordingdata["captureeffectpackets"] = [ ]
		var l = 0
		for packet in micrecordingdata["voipcapturepackets"]:
			var samples = handyopusnode.decode_opus_packet(packet)
			l += len(samples)
			micrecordingdata["captureeffectpackets"].append(samples)
		micrecordingdata.erase("voipcapturepackets")
		print("decoded from opus ", l)
		
		
func _on_SendRecord_pressed():
	if micrecordingdata != null:
		Dtoggleopuspackets()
		#rpc("remotesetmicrecord", micrecordingdata)
	if Dstorespeechfilename:
		print("saving ", ProjectSettings.globalize_path(Dstorespeechfilename))
		var fout = FileAccess.open(Dstorespeechfilename, FileAccess.WRITE)
		fout.store_var(micrecordingdata)
		fout.close()



func _on_PlayRecord_pressed():
	print("_on_PlayRecord_pressed")
	assert ($PlayRecord/AudioStreamPlayer.stream != null and $PlayRecord/AudioStreamPlayer.stream.is_class("AudioStreamGenerator"))

	if micrecordingdata != null and micrecordingdata.has("captureeffectpackets"):
		captureeffectpacketsplayback = micrecordingdata["captureeffectpackets"]
		captureeffectpacketsplaybackIndex = 0

	elif micrecordingdata != null and micrecordingdata.has("voipcapturepackets") and handyopusnode != null:
		voipcapturepacketsplayback = micrecordingdata["voipcapturepackets"]
		voipcapturepacketsplaybackIndex = 0
		voipcapturepacketsplaybackstart_msticks = Time.get_ticks_msec()
		voipcapturepacketsplayback_msduration = micrecordingdata["duration"]*1000

	elif micrecordingdata != null:
		print("Can't deal with micrecordingdata ", micrecordingdata.keys(), " (no AudioStreamVOIP class)")

	$PlayRecord/AudioStreamPlayer.play()
	playbackthing = $PlayRecord/AudioStreamPlayer.get_stream_playback()
