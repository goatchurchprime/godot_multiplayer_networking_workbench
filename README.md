# Godot4 Multiplayer networking workbench

This utility wraps the workings of the three [highlevel multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
networking protocols (**ENet**, **Websockets**, and **WebRTC**) into a plugin 
that can be dropped into any Godot project to enable it to be networked.
There are hooks to enable VR players to compress, transmit, unpack and interpolate their avatar movements across the network by sharing keyframes into the Animation system.

**WebRTC** enables peer to peer networking across the internet without a server.
The signalling (the exchange of a small amount of network routing data between the peers) 
is done using a light-weight MQTT server, of which public versions are available.

![image](https://github.com/user-attachments/assets/ce09a0c1-3b8e-43f7-b58e-cdb54f3733fb)

## Installation

This should run in Godot 4.3 or higher.  The reusable component is in `addons/player-networking`  
The system logic is embedded in a control panel that you can make invisible and operate externally with a 
restricted set of options tuned to your application, but it is exposed for the purpose of 
experimentation and debugging.

The pure GDScript **MQTT** addon is distributed with this application.  
A Godot project you can use to familiarize yourself with this protocol 
can be found [here](https://github.com/goatchurchprime/godot-mqtt?tab=readme-ov-file#mqtt)

If you want to use WebRTC you will need to use the \[AssetLib\] tab to install 
the [WebRTC plugin - Godot 4.1+](https://godotengine.org/asset-library/asset/2103) into 
the directory `addons/webrtc`.  (Although the WebRTC classes are in the core of GodotEngine, 
the implementation is kept separate to save 20Mbs for all the people not using this feature.) 

If you record and send opus-compressed voice packets over the net, you also need to 
install the [TwoVoip v3.4+](https://godotengine.org/asset-library/asset/3169) addon.
There is an **example** demo project in [two-voip-godot-4](https://github.com/goatchurchprime/two-voip-godot-4) 
demo project with that plugin for isolating the many VoIP related snags at this point.

## Operation

The **NetworkGateway** scene runs the entire process and is composed of a tree of UI Control nodes 
that can be used directly to visualize the state for debugging, or hidden behind another conventional multiplayer UI
such as a lobby (or "plaza", a term used to refer to players who can see one another on the MQTT server 
but have not partied-up into their chosen groups).

The main script **NetworkGateway.gd** manages the choice of protocol and the connections, while 
**PlayerConnections.gd** manages the players spawning and removal.

### Demo project

The toy example in this repo lets you show and hide the NetworkGateway panel, and \[Connect\] to the 
default WebRTC gateway.  This lets you talk to other players and see them move around their cursor.
![image](https://github.com/user-attachments/assets/190e8908-c553-4a67-bdcf-e296a033a6aa)

The lettered cards (make more with \[New Card\]) are synchronized by the `MultiplayerSpawner` and `MultiplayerSynchronizer`
nodes.  As you can see, they are out of sync with the players, who are moved by the Animation system.

Signalling is all done through the the public broker connected to [test.mosquitto.org](http://test.mosquitto.org/) and you can sniff out all the signals if you run the command:

> mosquitto_sub -h mosquitto.doesliverpool.xyz -t "cabbage/#" -v

This dumps everything in the room `cabbage` to the command line.  You can choose other rooms, so that connection 
can be like meet.jit.si.  

If you don't have WebRTC, you can connect using \[CS\] for Create ENET Server and \[CC\] for Connect as ENET client 
and it should all work on a local area network using UDP packet discovery.

## Out of date docs below here

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


