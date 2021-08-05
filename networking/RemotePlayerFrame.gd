extends Node

const CFI_ORIGINTRANS_POS	= 100
const CFI_ORIGINTRANS_QUAT 	= 110

var framedata0 = { }
remote func networkedavatarframedata(fd):
	get_parent().framedatatoavatar(fd)

remote func networkedavatarthinnedframedata(vd):
	if get_parent().get_name() == "Doppelganger":
		if vd.has(CFI_ORIGINTRANS_QUAT):
			vd[CFI_ORIGINTRANS_QUAT] *= Quat(Vector3(0,1,0), PI)
		if vd.has(CFI_ORIGINTRANS_POS):
			vd[CFI_ORIGINTRANS_POS] += Vector3(0,0,-2)
		
	for k in vd:
		framedata0[k] = vd[k]
	get_parent().framedatatoavatar(framedata0)

