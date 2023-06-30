extends ColorRect

func getnetoffset():
	return float($hbox/VBox_offset/netoffset.text)*0.001

func seteditable(b):
	$hbox/VBox_offset/netoffset.editable = b
	$hbox/VBox_delaymin/netdelaymin.editable = b
