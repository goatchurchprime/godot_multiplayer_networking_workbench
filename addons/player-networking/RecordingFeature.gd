extends GridContainer


@onready var PlayerConnections = find_parent("PlayerConnections")

# Opus compression settings
var opussamplerate_default = 48000 # 8, 12, 16, 24, 48 KHz
var opusframedurationms_default = 20 # 2.5, 5, 10, 20 40, 60
var opusbitrate_default = 10000  # 3000, 6000, 10000, 12000, 24000
var opuscomplexity_default = 5 # 0-10
var opusoptimizeforvoice_default = true

func _ready():
	#$TwoVoipMic.set_voxthreshhold(event.position.x/$VoxThreshold.size.x)
	$TwoVoipMic.initvoipmic($MicOn, $OptionInputDevice, $PTT, $Vox, $Denoise, $VoxThreshold.material)
	$TwoVoipMic.setopusvalues(opussamplerate_default, opusframedurationms_default, 2, opusbitrate_default, opuscomplexity_default, opusoptimizeforvoice_default)

func _on_vox_threshold_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		$TwoVoipMic.set_voxthreshhold(event.position.x/$VoxThreshold.size.x)

func _on_audio_stream_player_microphone_finished():
	print("*** _on_audio_stream_player_microphone_finished")
	$MicFinishedWarning.visible = true


func _on_mic_gain_db_value_changed(value):
	$TwoVoipMic.set_gain(db_to_linear(value))
