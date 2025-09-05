extends Node

var mintimestampoffset: float = 0.0
var laglatency = 0.2  # this needs to stay above almost all the arrivaldelay values
var initialframestate = 0

var networkID = 0   # 1:server, >1:connected as client
var logrecfile = null

var doppelgangerrecfile = null
var doppelgangerrectimeoffset = 0
var doppelgangernextrec = null
var NetworkGatewayForDoppelgangerReplay = null

var PlayerAnimation : AnimationPlayer = null
var currentplayeranimation : Animation = null
var currentplayeranimationT0 = 0.0
const animationtimerunoff = 5.0

func Dclearcachesig():
	pass # print("Dclearcachesig ", Time.get_ticks_msec())
func Dmixer_updated():
	print("Dmixerupdated ", Time.get_ticks_msec())

func setupanimationtracks(vd):
	PlayerAnimation = get_node_or_null("../PlayerAnimation")
	if PlayerAnimation == null or not PlayerAnimation.is_class("AnimationMixer"):
		printerr("PlayerScene must have PlayerAnimation:AnimationMixer")
	var currentplayeranimationlibrary = PlayerAnimation.get_animation_library("playeral")
	if currentplayeranimationlibrary == null:
		printerr("PlayerScene.PlayerAnimation must have animation library 'playeral'")
	if not currentplayeranimationlibrary.resource_local_to_scene:  # Avoids crash, see below
		printerr("PlayerScene.PlayerAnimation library 'playeral' must be local to scene")
		assert (false)
		
	var templateanimation : Animation = currentplayeranimationlibrary.get_animation("trackstemplate")
	if templateanimation == null:
		printerr("PlayerScene.PlayerAnimation library 'playeral' must have 'trackstemplate' animation")
	currentplayeranimation = templateanimation.duplicate()
	currentplayeranimationT0 = vd[NCONSTANTS.CFI_TIMESTAMP]
	currentplayeranimation.length = animationtimerunoff

	for i in range(currentplayeranimation.get_track_count()):
		currentplayeranimation.track_insert_key(i, 0, vd[NCONSTANTS.CFI_ANIMTRACKS + i])

	#var animname = "anim%d" % networkID
	var animname = "anim1"  # THIS CRASHES when 3 connections (2 animations same name)
	# See https://github.com/godotengine/godot/issues/98565

	currentplayeranimationlibrary.add_animation(animname, currentplayeranimation)
	PlayerAnimation.play("playeral/"+animname)
	PlayerAnimation.pause()
	PlayerAnimation.caches_cleared.connect(Dclearcachesig)
	PlayerAnimation.mixer_updated.connect(Dmixer_updated)

func startupremoteplayer(avatardata):
	get_parent().visible = false
	setupanimationtracks(avatardata["snapshottracks"])

func networkedavatarthinnedframedata(vd):
		# we could make this tolerate out of order values
	if logrecfile != null:
		logrecfile.store_var({"t":Time.get_ticks_msec()*0.001, "vd":vd})
	
	vd[NCONSTANTS.CFI_TIMESTAMP_RECIEVED] = Time.get_ticks_msec()*0.001
	var timestampoffset = vd[NCONSTANTS.CFI_TIMESTAMP_RECIEVED] - vd[NCONSTANTS.CFI_TIMESTAMP]
	if initialframestate == 0 or timestampoffset < mintimestampoffset:
		mintimestampoffset = timestampoffset
		print("new mintimeoffset ", timestampoffset)
		initialframestate = 1
	vd[NCONSTANTS.CFI_ARRIVALDELAY] = vd[NCONSTANTS.CFI_TIMESTAMP_RECIEVED] - mintimestampoffset - vd[NCONSTANTS.CFI_TIMESTAMPPREV]

	#assert (currentplayeranimation != null)
	if currentplayeranimation != null:
		for k in vd:
			if k >= NCONSTANTS.CFI_ANIMTRACKS:
				var i = k - NCONSTANTS.CFI_ANIMTRACKS
				var kt = vd[NCONSTANTS.CFI_TIMESTAMP] - currentplayeranimationT0
				#print(kt, "insertkey ", k)
				currentplayeranimation.track_insert_key(i, kt, vd[k])
				#print(" Dinsertkey ")
				if kt + animationtimerunoff > currentplayeranimation.length:
					currentplayeranimation.length = kt + animationtimerunoff

var Dframecount = 0
var Dmaxarrivaldelay = 0
func _process(delta):
	var Ttime = Time.get_ticks_msec()*0.001
	if doppelgangerrecfile != null and doppelgangernextrec != null:
		if doppelgangerrectimeoffset + Ttime > doppelgangernextrec.t:
			if doppelgangernextrec.has("vd"):
				networkedavatarthinnedframedata(doppelgangernextrec["vd"])
				doppelgangernextrec = doppelgangerrecfile.get_var()
			elif doppelgangernextrec.has("au"):
				$TwoVoipSpeaker.incomingaudiopacket(doppelgangernextrec["au"])
				doppelgangernextrec = doppelgangerrecfile.get_var()
			else:
				assert (doppelgangernextrec.has("END"))
				doppelgangernextrec = null
				NetworkGatewayForDoppelgangerReplay.DoppelgangerPanel.get_node("hbox/VBox_enable/DoppelgangerEnable").button_pressed = false
				
	if currentplayeranimation != null:
		var t = Ttime - mintimestampoffset - laglatency
		var kt = t - currentplayeranimationT0
		PlayerAnimation.seek(kt, true)

func incomingaudiopacket(packet):
	if logrecfile != null:
		logrecfile.store_var({"t":Time.get_ticks_msec()*0.001, "au":packet})
	$TwoVoipSpeaker.tv_incomingaudiopacket(packet)
	
func _ready():
	var playernode = get_parent()
	if playernode.has_method("PF_playvoicestream"):
		playernode.PF_setvoicestream($TwoVoipSpeaker.audiostreamopuschunked)
		playernode.PF_playvoicestream()
		$TwoVoipSpeaker.sigplaystream.connect(playernode.PF_playvoicestream)
		$TwoVoipSpeaker.sigvoicespeedrate.connect(playernode.PF_setvoicespeedup)

	else:
		print("Need an PF_playvoicestream for an AudioStreamPlayer node in RemotePlayer to do voip")
