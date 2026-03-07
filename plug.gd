@tool
extends "res://addons/gd-plug/plug.gd"

func _plugging():
	plug("goatchurchprime/godot-mqtt")
	plug("goatchurchprime/godot-webrtc-addon", {"branch":"v1.1.0"})
	plug("goatchurchprime/two-voip-addon", {"branch":"v4.1"})
