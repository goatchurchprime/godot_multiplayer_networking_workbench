extends HBoxContainer

var Ddisablevoip = false
var Dstorespeechfilename = "user://welcomespeech.dat"
var welcomespeechfilename = "res://addons/player-networking/welcomespeech.dat"

var micrecordingdata = null
const max_recording_seconds = 5.0

var recordingnumberC = 1
var recordingeffect = null
var capturingeffect = null

var voipcapturepackets = null
var voipcapturesize = 0
var voipinputcapture = null  # class VOIPInputCapture

var packetgaps = [ ]
var packettime = 0
func voip_packet_ready(packet): #New packet from mic to send
	if voipcapturepackets != null:
		voipcapturepackets.append(packet)
		voipcapturesize += len(packet)
		var Npackettime = Time.get_ticks_usec()
		packetgaps.append(Npackettime - packettime)
		packettime = Npackettime

var recordingstart_msticks = 0
var currentlyrecording = false

var voipcapturepacketsplayback = null
var voipcapturepacketsplaybackIndex = 0
var voipcapturepacketsplaybackstart_msticks = 0
var voipcapturepacketsplayback_msduration = 1

func _process(delta):
	if voipinputcapture:   # keep flushing it through
		voipinputcapture.send_test_packets()
	if currentlyrecording:
		if (Time.get_ticks_msec() - recordingstart_msticks)/1000 > max_recording_seconds:
			stop_recording()

	if voipcapturepacketsplayback != null:
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
	currentlyrecording = true
	recordingstart_msticks = Time.get_ticks_msec()
	if $VoipMode.button_pressed and voipinputcapture:
		voipcapturepackets = [ ]
		voipcapturesize = 0
		packetgaps = [ ]
	else:
		recordingeffect.set_recording_active(true)  # begins storing the bytes from a recording

func stop_recording():
	currentlyrecording = false
	var recording_duration = (Time.get_ticks_msec() - recordingstart_msticks)/1000.0 + 0.01
	var underlyingbytessize = 0
	if recordingeffect.is_recording_active():
		recordingeffect.set_recording_active(false)
		var recording = recordingeffect.get_recording()
		var pcmData = recording.get_data()
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
		voipcapturepackets = null
		print(packetgaps)
	print("created data bytes ", len(var_to_bytes(micrecordingdata)), " underlying ", underlyingbytessize)
	$RecordSize.text = "l-"+str(underlyingbytessize)

func _ready():
	if Ddisablevoip:
		set_process(false)  
		$MicRecord.disabled = true
		$MicRecord/AudioStreamRecorder.playing = false
		return
		
	var fin = FileAccess.open(welcomespeechfilename, FileAccess.READ)
	if fin:
		micrecordingdata = fin.get_var()
		fin.close()

	var recordbus_idx = AudioServer.get_bus_index("Recorder")
	assert ($MicRecord/AudioStreamRecorder.stream.is_class("AudioStreamMicrophone"))
	assert ($MicRecord/AudioStreamRecorder.bus == "Recorder")
	assert (AudioServer.is_bus_mute(recordbus_idx) == true)
	recordingeffect = AudioServer.get_bus_effect(recordbus_idx, 0)
	assert (recordingeffect.is_class("AudioEffectRecord"))

	# upgrade to OneVoip system if addon from https://github.com/RevoluPowered/one-voip-godot-4/ detected
	# The VOIPInputCapture taps off the stream leaving it the same, but feeds it to the Recorder
	print("dd ", ClassDB.can_instantiate("VOIPInputCapture"))
	print("dd ", ClassDB.can_instantiate("VOIPInputCapturasdasdae"))
	if ClassDB.can_instantiate("VOIPInputCapture"):
		var voipbusidx = AudioServer.get_bus_count()
		AudioServer.add_bus()
		assert (AudioServer.get_bus_name(voipbusidx).begins_with("New Bus"))
		AudioServer.set_bus_name(voipbusidx, "voiprecorder")
		voipinputcapture = ClassDB.instantiate("VOIPInputCapture")
		voipinputcapture.set_buffer_length(0.1)   # In the inhereted AudioEffectCapture 
		AudioServer.add_bus_effect(voipbusidx, voipinputcapture)
		AudioServer.set_bus_send(voipbusidx, "Recorder")
		$MicRecord/AudioStreamRecorder.bus = "voiprecorder"
		print($MicRecord/AudioStreamRecorder.bus)
		voipinputcapture.packet_ready.connect(voip_packet_ready)
		$VoipMode.button_pressed = true
	else:
		$VoipMode.disabled = true


func _on_MicRecord_button_down():
	if not currentlyrecording:
		start_recording()

func _on_MicRecord_button_up():
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
	elif micrecordingdata != null and micrecordingdata.has("voipcapturepackets") and ClassDB.can_instantiate("AudioStreamVOIP"):
		audioStream = ClassDB.instantiate("AudioStreamVOIP")
		voipcapturepacketsplayback = micrecordingdata["voipcapturepackets"]
		voipcapturepacketsplaybackIndex = 0
		voipcapturepacketsplaybackstart_msticks = Time.get_ticks_msec()
		voipcapturepacketsplayback_msduration = micrecordingdata["duration"]*1000
	else:
		print("Can't deal with micrecordingdata ", micrecordingdata.keys())
	if audioStream != null:
		$PlayRecord/AudioStreamPlayer.stream = audioStream
		$PlayRecord/AudioStreamPlayer.play()
