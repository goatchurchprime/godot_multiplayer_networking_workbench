extends MeshInstance2D

var mousecommandvelocity = Vector2(0, 0)
var mousebuttondown = false
var hithere=100


func _ready():
	var NetworkGateway = get_node("../../NetworkGateway")
	if OS.has_feature("Server"):
		await get_tree().create_timer(1.5).timeout
		NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS.AS_SERVER)


func _input(event):
	var mouseposition = null
	if event == null:
		pass
	elif event is InputEventScreenDrag or event is InputEventScreenTouch:
		return 
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				mouseposition = event.position
				print(mouseposition, "tss")
				mousebuttondown = true
			else:
				mousebuttondown = false
	elif event is InputEventMouseMotion and mousebuttondown:
		mouseposition = event.position
		
	if mouseposition != null and mouseposition.y-400 > 0:
		mousecommandvelocity = Vector2((-1 if mouseposition.x < mesh.size.x/3 else 0) + (1 if mouseposition.x > 2*mesh.size.x/3 else 0), 
										(-1 if mouseposition.y-400 < mesh.size.y/3 else 0) + (1 if mouseposition.y-400 > 2*mesh.size.y/3 else 0))
	else:
		mousecommandvelocity = Vector2(0, 0)
