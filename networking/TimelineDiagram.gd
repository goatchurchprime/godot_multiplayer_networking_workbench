extends Node2D


func marknetworkdataat(vd):
	var marker = Line2D.new()
	marker.width = 20.0
	var t = vd.get(NCONSTANTS.CFI_TIMESTAMP_RECIEVED, vd[NCONSTANTS.CFI_TIMESTAMP])
	var seglen = len(var2bytes(vd))/10.0+3.0
	marker.points = PoolVector2Array([Vector2(t*1000, 0), Vector2(t*1000, seglen)])
	if vd.has("playernodename"):
		$Players.get_node(vd["playernodename"]).get_node("TimeMarks").add_child(marker)
	else:
		$Players/LocalPlayer/TimeMarks.add_child(marker)

func newtimelineremoteplayer(avatardata):
	var remotetimelineplayernode = Node2D.new()
	remotetimelineplayernode.name = avatardata["playernodename"]
	var timemarks = Node2D.new()
	timemarks.name = "TimeMarks"
	remotetimelineplayernode.add_child(timemarks)
	remotetimelineplayernode.position = $Players.get_children()[-1].position + Vector2(0, 20)
	$Players.add_child(remotetimelineplayernode)
	
func removetimelineremoteplayer(playernodename):
	$Players.get_node(playernodename).queue_free()

func _process(delta):
	$CurrentTime.position.x = OS.get_ticks_msec()
	
func settimescalebar():
	var TimeScalebar = get_node("../../TimeScalebar")
	#TimeScalebar.points.set(1, Vector2($Camerafollownode/Camera2D.zoom.x, 0))
	TimeScalebar.points = PoolVector2Array([Vector2(0,0), Vector2(1000.0/($Camerafollownode/Camera2D.zoom.x), 0)])

func _ready():
	settimescalebar()

func zoomtimeline(relclick, s):
	var viewport = get_parent()
	var cp = relclick*get_parent().size
	var mpt = viewport.canvas_transform.affine_inverse().xform(cp)
	$Camerafollownode/Camera2D.zoom.x *= (1.5 if s < 0 else 1/1.5)
	var rv = viewport.canvas_transform.xform(mpt) - cp
	viewport.canvas_transform.origin -= rv
	var mpt1 = viewport.canvas_transform.affine_inverse().xform(cp)
	var screencentre = viewport.canvas_transform.affine_inverse().xform(Vector2(0.5, 0.5)*get_parent().size)
	$Camerafollownode/Camera2D.drag_margin_h_enabled = false
	$Camerafollownode/Camera2D.drag_margin_v_enabled = false
	$Camerafollownode.position = screencentre
	settimescalebar()
	
func _on_TimeTracking_toggled(button_pressed):
	$CurrentTime/RemoteTransform2D.update_position = button_pressed
	if button_pressed:
		$Camerafollownode/Camera2D.drag_margin_h_enabled = true
		$Camerafollownode/Camera2D.drag_margin_v_enabled = true
