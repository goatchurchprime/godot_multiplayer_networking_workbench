extends "res://addons/gd-plug/plug.gd"

func _plugging():
	plug("goatchurchprime/godot-mqtt")
	var stashedaddons = ["addons/twovoip", "addons/webrtc", "addons/godot-steam-audio"]
	plug("goatchurchprime/paraviewgodot", {"branch":"stashedaddons", "include":stashedaddons})
