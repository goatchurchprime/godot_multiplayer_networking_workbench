extends HBoxContainer

@onready var PlayerConnections = find_parent("PlayerConnections")

# Opus compression settings
var opussamplerate_default = 48000 # 8, 12, 16, 24, 48 KHz
var opusframedurationms_default = 20 # 2.5, 5, 10, 20 40, 60
var opusbitrate_default = 10000  # 3000, 6000, 10000, 12000, 24000
var opuscomplexity_default = 5 # 0-10
var opusoptimizeforvoice_default = true

func _ready():
	#$TwoVoipMic.set_voxthreshhold(event.position.x/$VoxThreshold.size.x)
	$TwoVoipMic.initvoipmic($MicOn, get_node("../HBoxDevices/OptionInputDevice"), $PTT, $Vox, $Denoise, $VoxThreshold.material)
	$TwoVoipMic.setopusvalues(opussamplerate_default, opusframedurationms_default, 2, opusbitrate_default, opuscomplexity_default, opusoptimizeforvoice_default)

	var OptionOutputDevice = $"../HBoxDevices/OptionOutputDevice"
	for d in AudioServer.get_output_device_list():
		OptionOutputDevice.add_item(d)
	assert(OptionOutputDevice.get_item_text(OptionOutputDevice.selected) == "Default")
	OptionOutputDevice.connect("item_selected", _on_optionoutputdevice)

func _on_optionoutputdevice(index: int) -> void:
	var output_device: String = $"../HBoxDevices/OptionOutputDevice".get_item_text(index)
	print("Set output device: ", output_device)
	AudioServer.set_output_device(output_device)

func _on_vox_threshold_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		$TwoVoipMic.set_voxthreshhold(event.position.x/$VoxThreshold.size.x)

func _on_audio_stream_player_microphone_finished():
	print("*** _on_audio_stream_player_microphone_finished")
	$MicFinishedWarning.visible = true


func _on_mic_gain_db_value_changed(value):
	$TwoVoipMic.set_gain(db_to_linear(value))
