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
	$PTT.toggle_mode = toggled_on
	$TwoVoipMic.voxenabled = toggled_on
	#$TwoVoipMic.pttpressed = false

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

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_K:
		$TwoVoipMic.microphonefeed.set_active(false)
		await get_tree().create_timer(0.5).timeout
		$TwoVoipMic.microphonefeed.set_active(false)

func micaudiowarning(name, value):
	get_node(name).visible = value
