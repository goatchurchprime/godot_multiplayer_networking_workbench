# Godot Multiplayer networking workbench

This is an application that exposes the workings of the various highlevel multiplayer networking methods 
in Godot on each of the three protocols (ENet, Websockets, and WebRTC).

https://docs.godotengine.org/en/stable/classes/class_networkedmultiplayerpeer.html#class-networkedmultiplayerpeer

download the webrtc libraries from here an put into webrtc directory:
https://github.com/godotengine/webrtc-native/releases

If having difficulties on linux, don't forget to try:
> sudo apt-get install libatomic1

If you are on Nixos, it needs patchelf to fix it:
> https://github.com/godotengine/webrtc-native/issues/44#issuecomment-922550575
