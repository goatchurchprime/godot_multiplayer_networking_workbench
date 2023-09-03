extends HBoxContainer



var micrecordingdata = null
const max_recording_seconds = 5.0
var recordingnumberC = 1
var recordingeffect = null
var capturingeffect = null

func _ready():
	#return
	var recordbus_idx = AudioServer.get_bus_index("Recorder")
	assert ($MicRecord/AudioStreamRecorder.bus == "Recorder")
	assert ($MicRecord/AudioStreamRecorder.stream.is_class("AudioStreamMicrophone"))
	assert (AudioServer.is_bus_mute(recordbus_idx) == true)
	recordingeffect = AudioServer.get_bus_effect(recordbus_idx, 0)
	assert (recordingeffect.is_class("AudioEffectRecord"))

	# we can use this capturing object ring buffer to collect and batch up chunks
	# see godot-voip demo.  Also how to use AudioStreamGeneratorPlayback etc
	#capturingeffect = AudioServer.get_bus_effect(recordbus_idx, 1)
	#assert (capturingeffect.is_class("AudioEffectCapture"))
	var enablesound = true
	if enablesound and ClassDB.class_exists("OpusEncoderNode"):
		if enablesound:
			var OpusEncoder = ClassDB.instantiate("OpusEncoderNode")
			OpusEncoder.name = "OpusEncoder"
			$MicRecord.add_child(OpusEncoder)
		else:
			print("Missing Opus plugin library")
		if enablesound and ClassDB.class_exists("OpusDecoderNode"):
			var OpusDecoder = ClassDB.instantiate("OpusDecoderNode")
			OpusDecoder.name = "OpusDecoder"
			$MicRecord.add_child(OpusDecoder)

	if $MicRecord.has_node("OpusDecoder"):
		var fname = "res://addons/player-networking/welcomespeech.opusbin"
		if FileAccess.file_exists(fname):
			micrecordingdata = { "format":1, "mix_rate":44100, "is_stereo":true }
			micrecordingdata["opusEncoded"] = FileAccess.get_file_as_bytes(fname)
			$RecordSize.text = "w-"+str(len(micrecordingdata.get("opusEncoded", micrecordingdata.get("pcmData"))))

func _on_MicRecord_button_down():
	if not recordingeffect.is_recording_active():
		recordingnumberC += 1
		micrecordingdata = null
		await get_tree().create_timer(0.1).timeout
		var lrecordingnumberC = recordingnumberC
		recordingeffect.set_recording_active(true)
		await get_tree().create_timer(max_recording_seconds).timeout
		if micrecordingdata != null and lrecordingnumberC == recordingnumberC:
			_on_MicRecord_button_up()
		if OS.get_name() == "X11":
			print("Warning mic doesn't work on Linux (godot issue 33184)")  # seems to work on my nix machine
		
func _on_MicRecord_button_up():
	if recordingeffect.is_recording_active():
		recordingeffect.set_recording_active(false)
		var recording = recordingeffect.get_recording()
		var pcmData = recording.get_data()
		micrecordingdata = { "format":recording.get_format(), 
							"mix_rate":recording.get_mix_rate(),
							"is_stereo":recording.is_stereo() }
		if $MicRecord.has_node("OpusEncoder"):
			micrecordingdata["opusEncoded"] = $MicRecord/OpusEncoder.encode(pcmData)
		else:
			micrecordingdata["pcmData"] = pcmData
		print(" created data bytes ", len(var_to_bytes(micrecordingdata)), "  ", len(pcmData))
		$RecordSize.text = "l-"+str(len(micrecordingdata.get("opusEncoded", micrecordingdata.get("pcmData"))))

@rpc("any_peer") func remotesetmicrecord(lmicrecordingdata):
	micrecordingdata = lmicrecordingdata
	$RecordSize.text = "r-"+str(len(micrecordingdata.get("opusEncoded", micrecordingdata.get("pcmData"))))
	

func _on_SendRecord_pressed():
	if micrecordingdata != null:
		rpc("remotesetmicrecord", micrecordingdata)
	#var fout = File.new()
	#var fname = "user://welcomespeech.dat"
	#print("saving ", ProjectSettings.globalize_path(fname))
	#fout.open(fname, File.WRITE)
	#fout.store_var(micrecordingdata)
	#fout.close()

func _on_PlayRecord_pressed():
	print("_on_PlayRecord_pressed")
	if micrecordingdata != null:
		var audioStream = AudioStreamWAV.new()
		audioStream.set_format(micrecordingdata["format"])
		audioStream.set_mix_rate(micrecordingdata["mix_rate"])
		audioStream.set_stereo(micrecordingdata["is_stereo"])
		if micrecordingdata.has("opusEncoded") and $MicRecord.has_node("OpusDecoder"):
			audioStream.data = $MicRecord/OpusDecoder.decode(micrecordingdata["opusEncoded"])
			print("audio playing bytes ", len(audioStream.data))
		elif micrecordingdata.has("pcmData"):
			audioStream.data = micrecordingdata["pcmData"]
			print("audio playing bytes ", len(audioStream.data))
		else:
			print("No decodable audio data here")
		$PlayRecord/AudioStreamPlayer.stream = audioStream
		$PlayRecord/AudioStreamPlayer.play()
