# Godot4 Multiplayer networking workbench

hi there

This utility wraps the workings of the three [highlevel multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
networking protocols (**ENet**, **Websockets**, and **WebRTC**) 
and has hooks to enable VR players to compress, transmit, unpack and interpolate their avatar movements across the network.

**WebRTC** enables peer to peer networking across the internet without a server.  
The signalling (the exchange of a small amount of network routing data between the peers) 
is done using a light-weight MQTT server, of which public versions are available.

![image](https://github.com/goatchurchprime/godot_multiplayer_networking_workbench/assets/677254/b49e2b09-b5cd-46a7-9a75-16d3dd5cf8d9)

## Installation

This should run in Godot 4.2 or higher.  The reusable component is in `addons/player-networking`  
The system logic is embedded in a control panel that you can make invisible and operate externally with a 
restricted set of options tuned to your application, but it is exposed for the purpose of debugging.

The pure GDScript **MQTT** addon is distributed with this application.

You can download and install the **WebRTC** and **twovoip** binary addons directly from the `AssetLib`.

The **twovoip** provides the nodes `AudioEffectOpusChunked` and `AudioStreamOpusChunked` 
to compress and decompress audio through the [Opus Voice Compression codec](https://opus-codec.org/).
If you have any problem with this VoIP system, 
try the [two-voip-godot-4](https://github.com/goatchurchprime/two-voip-godot-4) demo project directly which 
will find out what the snags are.

## Operation

The **NetworkGateway** scene runs the entire process and is composed of a tree of UI Control nodes 
that can be used directly to visualize the state for debugging, or hidden behind another conventional multiplayer UI
such as a lobby.

The main script **NetworkGateway.gd** manages the choice of protocol and the connections, while **PlayerConnections.gd** manages 
the players spawning and removal.

### Network connecting

The toy example included is an ineffective pong game with the network provisioning code in the `JoystickControls.gd` script.
We connect using WebRTC at startup so it works out of the box.  This is done with the call to `NetworkGateway.initialstatemqttwebrtc()`

Signalling is all done through the the public broker connected to [test.mosquitto.org](http://test.mosquitto.org/) and you can sniff 
out all the signals if you run the command:

> mosquitto_sub -h test.mosquitto.org -t "lettuce/#" -v

This dumps everything in the room `lettuce` to the command line.  You can choose other rooms, so that connection 
can be like meet.jit.si.  

The use of a public MQTT broker to initiate the connections means we can set the connection to "As necessary", which means 
that if there's live server on the channel it starts out as a server, otherwise it starts as a client and connects to it.
(Automatic handover code for when the server drops out is partly working, but unreliable, and could be finished if 
there is a sufficient use-case.)

You can select a different protocol (ENet or Websockets) when the Network is off, and then select server or client.
There will be UDP packets sent by the server to help any clients on the same router network to find and connect to it 
without needing to look up the local IP number.  (Or you can set this running on a external server with a fixed IP number 
on the internet)

### Players

By default it uses the path `/root/Main/Players` as the node that keeps the players together, and considers the first node in there 
as the **LocalPlayer**.

The LocalPlayer gets a **PlayerFrame** node the the **PlayerFrameLocal.gd** script associated to it.  
Any remote players that are created are included with the same, but with the **PlayerFrameRemote.gd** script attached to it.
These are the scripts which receive the player motions generated locally and unpack and animate the 
player motions remotely. 

These PlayerFrame nodes are what all the rpc() calls are made against.  The Player nodes are given consistent names 
across the network based on the networkID so that these rpc() calls, which depend on finding the same node in the tree across different 
instances in the game, are able to work.

The script attached to the Player (the node containing the PlayerFrame that visualizes the avatar) must have the following functions:

* func PAV_initavatarlocal(): Called at startup on the LocalPlayer

* func PAV_initavatarremote(avatardata): Called when a new RemotePlayer is created in the Players node

* func PAV_avatarinitdata() -> avatardata: The dict of data called on the LocalPlayer and sent to the function above

* func playername(): Used in the Networking UI to list the players

* func PAV_processlocalavatarposition(delta):  Called directly from the PlayerFrameLocal \_process() function before it reads the position

* func PAV_avatartoframedata() -> fd: dict of local player position state generated at each frame

* func PAV_framedatatoavatar(fd):  The unpacking of the remote player position state from the frame data.

* func PAV_createspawnpoint():  The server generates a span point for each client

* func PAV_receivespawnpoint(sfd): The spawn point as received from the server after connection


* static func changethinnedframedatafordoppelganger(fd, doppelnetoffset): A function used to distort the set of frame data so it can be used as a player doppelganger 
to see how the motions would look on the other side of a network in real time.

To avoid a huge load on the network, the PlayerFrameLocal.gd and PlayerFrameRemote.gd scripts automatically thins down the 
data generated by avatartoframedata() and interpolates the gaps in the data for framedatatoavatar() respectively.
This depends on timestamps and estimates of network latency etc and is where the hard work needs to be done.

## Audio

The audio chunks are 20ms long and are compressed to about 30bytes each to give roughly a 1.5kB/second audio data channel.
It's either operated by PTT (Push-to-talk) or VoX (Voice operated switch), so it's not intended to be a continuous stream.

The Remote Player needs a node called `AudioStreamPlayer` that the `PlayerFrameRemote` object pushes its audio packets to.  
This can be type `AudioStreamPlayer3D` or `AudioStreamPlayer2D` (even though these don't inheret from the same type).


