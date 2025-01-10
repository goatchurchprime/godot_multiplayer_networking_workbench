# Godot4 Multiplayer networking workbench

This utility wraps the workings of the three [highlevel multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
networking protocols (**ENet**, **Websockets**, and **WebRTC**) into a plugin that can be dropped into any Godot project to enable it to be networked.

The plugin is optimized for use for Virtual Reality (VR/XR) players and their avatars, but it can be a starting point for any multiplayer application.  Multiplayer game design is a very wide field, and this plugin is for exploring game mechanics and technical requirements as quickly as possible so as to inform early game design-- _and how you are going to avoid depending on realtime interactive physics if you know what is good for you!_

### Lightning talk at GodotCon2024
[![image](https://github.com/user-attachments/assets/b8a64026-3cf3-42bd-a080-d45eeeefba05)](https://www.youtube.com/watch?v=iyRvLdhATFo)

**WebRTC** enables peer to peer networking across the internet without a server.
The signalling (the exchange of a small amount of network routing data between the peers) 
is done using a light-weight MQTT server, of which public versions are available.

![image](https://github.com/user-attachments/assets/ce09a0c1-3b8e-43f7-b58e-cdb54f3733fb)

## Installation

This should run in Godot 4.3 or higher.  The reusable component is in `addons/player-networking`  
The system logic is embedded in a control panel that you can make invisible and operate externally with a 
restricted set of options tuned to your application, but it is exposed for the purpose of 
experimentation and debugging.

### Addons

Addons that are missing can be downloaded from the **AssetLib** tab once you open the project.

* [mqtt-client](https://godotengine.org/asset-library/asset/1993) v1.2 is already included because it is very small and pure GDScript

* [TwoVoip](https://godotengine.org/asset-library/asset/3169) v3.6 is required to compress your audio stream 
from the microphone using the Opus library.  It can be used on its own for testing from [two-voip-godot-4](https://github.com/goatchurchprime/two-voip-godot-4)
The asset is 100Mb, so is not included with the project.  **A version of the Godot Engine compiled with
[Pull Request#100508](https://github.com/godotengine/godot/pull/100508) is recommended for a more reliable implementation of the microphone input.**

* [WebRTC plugin - Godot 4.1+](https://godotengine.org/asset-library/asset/2103) is required to implement the WebRTC protocol and 
is also about 100Mb in size (because it has the implementation for all platforms).  
Make sure you set its download directory to `addons/webrtc`.  

* **addons/player-networking** is the addon that this project is a demo for.  It is not yet ready to be 
released as an addon it its own right.
 

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

## The plaza area

The on-boarding, match-making, authentication and lobby systems provided by many third-party multiplayer management services 
is usually very specialized and complex.  This plugin is designed to get to the point without any unnecessary hassle, accounts 
or external servers.  

Any number of players can connect to a given room/topic on an MQTT server provided they each pick a random `client_id`.  
The initial state us `unconnected` to any Game server (though connected to the MQTT server in a way that lets them see 
where all the players in that room are in relation to other game servers.  You can enter this state by selecting 
`As necessary manual`.  

The MQTT interface gives an easy platform on which to exchange text messages and identity tokens you can use to .
verify who your friends are should it be necessary.

![image](https://github.com/user-attachments/assets/cd83f90f-643f-4755-944e-0e64723ece3f)

Any player in a room can assign themselves `As server` in a room.  They are then deemed to have connected to themself as a Game server.  
Any other player can select a player who is a Game server and assign themselves `As client` to that server.
The option `As necessary` is to automate the process of checking if there is a player who is a Game server in a room, and assigning 
themselve as a client, or upgrading themselves to a Game server if no suitable one exists.

Once a Game server player has accepted another player as a client, the WebRTC connection between them is established through 
which VoIP and [High Level Multiplayer operations](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html) 
can proceed.  This Multiplayer Workbench addon manages the player connections and on-boarding to provide you with 
an even higher level multiplayer interface that can be dropped into any game with a minimum of hassle.


### Players

By default it uses the path `/root/Main/Players` as the node that keeps the players together, and considers the first node in there 
as the **LocalPlayer**.

The LocalPlayer gets a **PlayerFrame** node the the **PlayerFrameLocal.gd** script associated to it.  
Any remote players that are created are included with the same, but with the **PlayerFrameRemote.gd** script attached to it.
These are the scripts that interpret player motions locally, sends the data to a remote player where it is 
unpacked and injected into an AnimationPlayer that animates the player. 

A player must have an `AnimationPlayer` node called `PlayerAnimation` that lists all the tracks that are to be replicated across the network by calling the function `PlayerFrameLocal.recordthinnedanimation()`.  This has a lot of similarities to the `MultiplayerSyncronizer` type node which lists the properties that are to 
be syncronized.  The difference here is that since an `AnimationPlayer` can interpolate between keyframes we do not need to transmit 
everything about the player in each frame, and can thin out the values.

The script attached to the LocalPlayer (the node containing the LocalPlayerFrame) must have at least the following functions:

* **PF_initlocalplayer()**: Called at startup on the LocalPlayer from `PlayerConnections._ready()`

* **PF_spawninfo_fornewplayer**: Called by `PlayerConnections._peer_connected()` on the server

* **PF_spawninfo_receivedfromserver()**: Called by `PlayerConnections.RPC_spawninfoforclientfromserver()` to set the position of the remote player before joining the server (for management of spawn points).

* **PF_processlocalavatarposition(delta)**: Called by `PlayerFrameLocal._process()` to ensure that the local player's position can be processed as soon as it is updated.

* **PF_setspeakingvolume(v)**: Called by `RecordingFeature.process()` to give some indication of voice activity.  In the future this might be a set of visemes.

* **PF_changethinnedframedatafordoppelganger(vd, doppelnetoffset)**: Called by `PlayerFrameLocal._process()` with the current position of the the player so it can be transformed so that the doppelganger can be seen and not be coinciding with the player.

* **PlayerAnimation**: Not a function, but a child node of type `AnimationPlayer` containing tracks that reference the parameters that are to be shared across the network to animate the remote player instance.

By default the **LocalPlayer** and **RemotePlayer** instances of the same scene whose file reference is `avatarsceneresource`.  They differ by having a **PlayerFrameLocal** or **PlayerFrameRemote** added as a child.  

### Audio

The audio chunks are 20ms long and are compressed to about 30bytes each to give roughly a 1.5kB/second audio data channel.
It's either operated by PTT (Push-to-talk) or VoX (Voice operated switch), so it's not intended to be a continuous stream.

The Remote Player needs a node called `AudioStreamPlayer` that the `PlayerFrameRemote` object pushes its audio packets to.  
This can be type `AudioStreamPlayer3D` or `AudioStreamPlayer2D` (even though these don't inheret from the same type).


