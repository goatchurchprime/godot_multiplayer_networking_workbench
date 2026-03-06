extends "res://addons/gd-plug/plug.gd"

func _plugging():
	plug("goatchurchprime/godot-mqtt")
	var stashedaddons = ["addons/webrtc"]
	plug("goatchurchprime/paraviewgodot", {"branch":"stashedaddons", "include":stashedaddons})
	#plug("goatchurchprime/two-voip-addon", {"tag":"v4.0"})
