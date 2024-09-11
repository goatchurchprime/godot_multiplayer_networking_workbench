extends Control


@onready var MQTTsignalling = find_parent("MQTTsignalling")
@onready var MQTT = MQTTsignalling.get_node("MQTT")
@onready var StartMQTT = MQTTsignalling.get_node("VBox/HBox2/StartMQTT")
@onready var StartMQTTstatuslabel = MQTTsignalling.get_node("VBox/HBox2/statuslabel")


# these might be superfluous if we are using the MQTT.client_id plus a character
var clientidtowclientid = { }
var wclientidtoclientid = { }

signal mqttsig_client_connected(id)
signal mqttsig_client_disconnected(id)
signal mqttsig_packet_received(id, v)

# Messages: topic: room/x<mqttclientid>/status 
#           topic: room/x<mqttclientid>/packet/<clientid-to>
# 			payload: {"subject":type, ...}

func sendpacket_toclient(wclientid, v):
	var t = "%s/%s/packet/%s" % [MQTTsignalling.roomname, MQTT.client_id, wclientidtoclientid[wclientid]]
	print(" >>> packet to client ", t, v)
	MQTT.publish(t, JSON.stringify(v))
	
func Dreceived_mqtt(stopic, v):
	if v != null and v.has("subject"):
		if len(stopic) >= 3 and stopic[0] == MQTTsignalling.roomname:
			var sendingclientid = stopic[1]
			
			if len(stopic) >= 4 and stopic[-2] == "packet" and stopic[-1] == MQTT.client_id:
				if clientidtowclientid.has(sendingclientid):
					emit_signal("mqttsig_packet_received", clientidtowclientid[sendingclientid], v)
				elif v["subject"] == "request_connection":
					var wclientid = int(sendingclientid)
					clientidtowclientid[sendingclientid] = wclientid
					wclientidtoclientid[wclientid] = sendingclientid
					var t = "%s/%s/packet/%s" % [MQTTsignalling.roomname, MQTT.client_id, sendingclientid]
					MQTT.publish(t, JSON.stringify({"subject":"connection_prepared", "wclientid":wclientid}))
					MQTT.publish(MQTTsignalling.statustopic, JSON.stringify({"subject":"serveropen", "nconnections":len(clientidtowclientid)}), true)
					MQTTsignalling.publishstatus("serveropen", "", len(clientidtowclientid))
					emit_signal("mqttsig_client_connected", wclientid)
					$ClientsList.add_item(sendingclientid, int(sendingclientid))
					$ClientsList.selected = $ClientsList.get_item_count()-1
				
			elif len(stopic) == 3 and stopic[2] == "status":
				if v["subject"] == "closed":
					if clientidtowclientid.has(sendingclientid):
						var wclientid = clientidtowclientid[sendingclientid]
						emit_signal("mqttsig_client_disconnected", wclientid)
						clientidtowclientid.erase(sendingclientid)
						wclientidtoclientid.erase(wclientid)
						var idx = $ClientsList.get_item_index(int(sendingclientid))
						print(idx)
						$ClientsList.remove_item(idx)
						MQTTsignalling.publishstatus("serveropen", "", len(clientidtowclientid))

				if v["subject"] == "serveropen":
					if stopic[1] == MQTT.client_id:
						print("found openserver myself: ", stopic[1], v)

			else:
				print("Unrecognized topic ", stopic)

	
		
