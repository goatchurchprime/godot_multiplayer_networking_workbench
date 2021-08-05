extends Node


var framedata0 = { }
remote func networkedavatarframedata(fd):
	get_parent().framedatatoavatar(fd)

remote func networkedavatarthinnedframedata(vd):
	for k in vd:
		framedata0[k] = vd[k]
	get_parent().framedatatoavatar(framedata0)

