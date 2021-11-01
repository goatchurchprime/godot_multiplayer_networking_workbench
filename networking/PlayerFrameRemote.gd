extends Node


var framedata0 = { }
remote func networkedavatarframedata(fd):
	get_parent().framedatatoavatar(fd)

func networkedavatarthinnedframedata(vd):
	vd["received_timestamp"] = OS.get_ticks_msec()*0.001
	for k in vd:
		framedata0[k] = vd[k]
	get_parent().framedatatoavatar(framedata0)

