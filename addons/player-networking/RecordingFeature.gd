extends HBoxContainer

var Ddisablevoip = false
var Dstorespeechfilename = "user://welcomespeech.dat"
var welcomespeechfilename = "res://addons/player-networking/welcomespeech.dat"

var micrecordingdata = null
const max_recording_seconds = 5.0

var recordingnumberC = 1
var recordingeffect = null

var spectrumanalyzereffect = null

var voipcapturepackets = null
var voipcapturesize = 0
var voipinputcapture = null  # class VOIPInputCapture

#GODOT_SAMPLE_RATE = 44100;
#OPUS_FRAME_SIZE = 480;  10ms
#OPUS_SAMPLE_RATE = 48000;
#godot_frame_size = 441 = OPUS_FRAME_SIZE * GODOT_SAMPLE_RATE / OPUS_SAMPLE_RATE = 


var packetgaps = [ ]
var testpacketnumber = 0
var packettime = 0
func voip_packet_ready(packet): #New packet from mic to send
	if voipcapturepackets != null:
		voipcapturepackets.append(packet)
		voipcapturesize += len(packet)
		var Npackettime = Time.get_ticks_usec()
		#packetgaps.append(Npackettime - packettime)
		packetgaps.append(testpacketnumber)
		packettime = Npackettime
		print("voip_packet_ready ", testpacketnumber)		

var recordingstart_msticks = 0
var currentlyrecording = false

var voipcapturepacketsplayback = null
var voipcapturepacketsplaybackIndex = 0
var voipcapturepacketsplaybackstart_msticks = 0
var voipcapturepacketsplayback_msduration = 1

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
var staticvoipaudiostream = null
# steal the viseme code from https://github.com/Malcolmnixon/godot-lip-sync/blob/main/addons/godot-lip-sync/lip_sync.gd

func _process(delta):
	if not audiostreamrecorder.playing and Donceaudio:
		print("s-- Rec not playing")
		Donceaudio = false
	if voipinputcapture:   # keep flushing it through
		if true and voipinputcapture.has_method("_sample_buf_to_packet"):
			while voipinputcapture.get_frames_available() >= 441:
				var samples = voipinputcapture.get_buffer(441)
				#var packet = voipinputcapture._sample_buf_to_packet(samples)
				var packet = handyopusnodeencoder.encode_opus_packet(samples)
				voip_packet_ready(packet)
			testpacketnumber += 1
		else:
			voipinputcapture.send_test_packets()
			testpacketnumber += 1

		
	if currentlyrecording:
		if (Time.get_ticks_msec() - recordingstart_msticks)/1000 > max_recording_seconds:
			stop_recording()

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
				$PlayRecord/AudioStreamPlayer.stop()
				$PlayRecord/AudioStreamPlayer.stream = null

func start_recording():
	print("start_recording")
	currentlyrecording = true
	recordingstart_msticks = Time.get_ticks_msec()
	if not audiostreamrecorder.playing:
		print("MicRecord/AudioStreamRecorder not playing (autoplay setting failed), trying to set now")
		audiostreamrecorder.playing = true
	if $VoipMode.button_pressed and voipinputcapture:
		voipcapturepackets = [ ]
		voipcapturesize = 0
		packetgaps = [ ]
		testpacketnumber = 0
	else:
		recordingeffect.set_recording_active(true)  # begins storing the bytes from a recording

func stop_recording():
	print("stop_recording")
	currentlyrecording = false
	var recording_duration = (Time.get_ticks_msec() - recordingstart_msticks)/1000.0 + 0.01
	var underlyingbytessize = 0
	if recordingeffect.is_recording_active():
		recordingeffect.set_recording_active(false)
		var recording = recordingeffect.get_recording()
		var pcmData = recording.get_data() if recording else PackedByteArray()
		micrecordingdata = { "format":recording.get_format(), 
							"mix_rate":recording.get_mix_rate(),
							"is_stereo":recording.is_stereo(),
							"duration":recording_duration, 
							"pcmData":pcmData }
		underlyingbytessize = len(pcmData)
	elif voipcapturepackets:
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

func _ready():
	if ClassDB.can_instantiate("HandyOpusNode"):
		handyopusnode = ClassDB.instantiate("HandyOpusNode")#
		handyopusnodeencoder = ClassDB.instantiate("HandyOpusNode")#
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
	recordingeffect = AudioServer.get_bus_effect(recordbus_idx, 0)
	assert (recordingeffect.is_class("AudioEffectRecord"))
	spectrumanalyzereffect = AudioServer.get_bus_effect_instance(recordbus_idx, 1)
	print(spectrumanalyzereffect)

	# upgrade to OneVoip system if addon from https://github.com/RevoluPowered/one-voip-godot-4/ detected
	# The VOIPInputCapture taps off the stream leaving it the same, but feeds it to the Recorder
	if true and ClassDB.can_instantiate("VOIPInputCapture"):
		if not ProjectSettings.get_setting("audio/driver/enable_input"):
			printerr("Need ProjectSettings audio/driver/enable_input to be True for the mic to work!")
		var voipbusidx = AudioServer.get_bus_count()
		AudioServer.add_bus()
		assert (AudioServer.get_bus_name(voipbusidx).begins_with("New Bus"))
		AudioServer.set_bus_name(voipbusidx, "voiprecorder")
		voipinputcapture = ClassDB.instantiate("VOIPInputCapture")
		voipinputcapture.set_buffer_length(0.5)   # In the inhereted AudioEffectCapture 
		AudioServer.add_bus_effect(voipbusidx, voipinputcapture)
		AudioServer.set_bus_send(voipbusidx, "Recorder")
		audiostreamrecorder.bus = "voiprecorder"
		print("audiostreamrecorder bus ", audiostreamrecorder.bus)
		voipinputcapture.packet_ready.connect(voip_packet_ready)
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
	$RecordSize.text = "r-"+str(len(micrecordingdata.get("voipcapturepackets", micrecordingdata.get("pcmData"))))

func _on_SendRecord_pressed():
	if micrecordingdata != null:
		rpc("remotesetmicrecord", micrecordingdata)
	if Dstorespeechfilename:
		print("saving ", ProjectSettings.globalize_path(Dstorespeechfilename))
		var fout = FileAccess.open(Dstorespeechfilename, FileAccess.WRITE)
		fout.store_var(micrecordingdata)
		fout.close()



func _on_PlayRecord_pressed():
	print("_on_PlayRecord_pressed")
	var audioStream = null

	if micrecordingdata != null and micrecordingdata.has("pcmData"):
		audioStream = AudioStreamWAV.new()
		audioStream.set_format(micrecordingdata["format"])
		audioStream.set_mix_rate(micrecordingdata["mix_rate"])		
		audioStream.set_stereo(micrecordingdata["is_stereo"])
		audioStream.data = micrecordingdata["pcmData"]
		print("audioslice ", audioStream.data.slice(int(len(audioStream.data)/2), int(len(audioStream.data)/2)+50))

	elif micrecordingdata != null and micrecordingdata.has("voipcapturepackets") and ClassDB.can_instantiate("AudioStreamVOIP"):
		audioStream = ClassDB.instantiate("AudioStreamVOIP")
		if audioStream.has_method("spush_packet"):
			staticvoipaudiostream = audioStream
			print("Using spush_packet")
			audioStream = ClassDB.instantiate("AudioStreamGenerator")
			voipcapturepacketsplayback = micrecordingdata["voipcapturepackets"]
			voipcapturepacketsplaybackIndex = 0

		else:

			voipcapturepacketsplayback = micrecordingdata["voipcapturepackets"]
			voipcapturepacketsplaybackIndex = 0
			voipcapturepacketsplaybackstart_msticks = Time.get_ticks_msec()
			voipcapturepacketsplayback_msduration = micrecordingdata["duration"]*1000


	elif micrecordingdata != null:
		print("Can't deal with micrecordingdata ", micrecordingdata.keys(), " (no AudioStreamVOIP class)")
	if audioStream != null:
		$PlayRecord/AudioStreamPlayer.stream = audioStream
		$PlayRecord/AudioStreamPlayer.play()
		if staticvoipaudiostream != null and audioStream.is_class("AudioStreamGenerator"):
			playbackthing = $PlayRecord/AudioStreamPlayer.get_stream_playback()
