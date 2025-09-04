extends HBoxContainer


@onready var PlayerConnections = find_parent("PlayerConnections")

# Opus compression settings
var opussamplerate_default = 48000 # 8, 12, 16, 24, 48 KHz
var opusframedurationms_default = 20 # 2.5, 5, 10, 20 40, 60
var opusbitrate_default = 10000  # 3000, 6000, 10000, 12000, 24000
var opuscomplexity_default = 5 # 0-10
var opusoptimizeforvoice_default = true

func _ready():
	$TwoVoipMic.audiosampleframematerial = $VoxThreshold.material
	$TwoVoipMic.audiosampleframematerial.set_shader_parameter("voxthreshhold", $TwoVoipMic.voxthreshhold)
	$TwoVoipMic.micaudiowarnings.connect(micaudiowarning)

	if $TwoVoipMic.audioopuschunkedeffect != null:
		$TwoVoipMic.setopusvalues(opussamplerate_default, opusframedurationms_default, opusbitrate_default, opuscomplexity_default, opusoptimizeforvoice_default)
	else:
		printerr("Unabled to find or instantiate AudioEffectOpusChunked on MicrophoneBus")
		$OpusWarningLabel.visible = true

func _on_vox_toggled(toggled_on):
	if toggled_on:
		$TwoVoipMic.voxenabled = true
		$PTT.toggle_mode = true
		$TwoVoipMic.pttpressed = false
	else:
		$TwoVoipMic.voxenabled = false
		$PTT.toggle_mode = false
		$TwoVoipMic.pttpressed = $PTT.button_pressed

func _process(delta):
	if $TwoVoipMic.voxenabled:
		$PTT.set_pressed_no_signal($TwoVoipMic.pttpressed)
	else:
		$TwoVoipMic.pttpressed = $PTT.button_pressed

func _on_denoise_toggled(toggled_on):
	$TwoVoipMic.denoiseenabled = toggled_on

func _on_vox_threshold_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		$TwoVoipMic.voxthreshhold = event.position.x/$VoxThreshold.size.x
		$VoxThreshold.material.set_shader_parameter("voxthreshhold", $TwoVoipMic.voxthreshhold)

func _on_audio_stream_player_microphone_finished():
	print("*** _on_audio_stream_player_microphone_finished")
	$MicFinishedWarning.visible = true

func micaudiowarning(name, value):
	get_node(name).visible = value

func _on_mic_gain_db_value_changed(value):
	$TwoVoipMic.audioopuschunkedeffect.volume_db = value
