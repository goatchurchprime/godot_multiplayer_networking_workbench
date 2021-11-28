extends KinematicBody2D

var velocity = Vector2(10, 5)
#var velocity = Vector2(100, 50)

func _physics_process(delta):
	while true:
		var rel_vec = velocity*delta
		var k = move_and_collide(rel_vec)
		if k == null:
			break
		delta = k.remainder.length() / velocity.length()
		var tval = k.normal.tangent().dot(velocity)
		var vval = -k.normal.dot(velocity) + k.normal.dot(k.collider_velocity)
		velocity = k.normal.tangent()*tval + k.normal*vval 
	var rs = get_parent().rect_size
	if position.y > rs.y:
		position.y -= rs.y
	if position.y < 0:
		position.y += rs.y
	velocity = velocity*(1-delta*0.2)



func _on_PingPongBall_area_entered(area):
	var contactvec = area.global_position - global_position
	print("area entered ", area.global_position, global_position, contactvec)
