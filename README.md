This repository contains a standalone script to connect an Hydrao shower head to Home Assistant via MQTT.
It also contains a work-in-progress wireshark dissector for the hydrao protocol.

## Requirements

- Home Assistant and a MQTT server
- a bluetooth adapter
- the mac address of the hydrao shower head
- python >= 3.7

## How-to

```
pip install -r requirements.txt
export MQTT_SERVER=1.2.3.4
export MQTT_PORT=1883
export MQTT_USER=my_user
export MQTT_PASSWORD=abcdef
python ./receiver.py shower_head_mac_address
```

I'm running this script as a long running systemd service on a raspberry 2 located next to the bathroom.

## Credits

Code has been built my copy-pasting multiple existing scripts found to interact with bluetooth devices. If you recognize your code, drop me a note, I'll credit you.

# Other files

I've done a few dumps from the exchange between my first (and then my second) shower head and my phone while using the app.
All the .log, .pcap and .pcanpng  files are those dumps. The latter is commented with my first findings.
Open them with the wireshark dissector to get my current understanding of the protocol.

Decoded fields:
- volume of current shower
- volume of the last x showers
- color and thresholds
- firmware and hardware versions
- shower head device id

Undecoded fields: temperature and water flow.

### Some help from internet wisdom

In french: https://community.jeedom.com/t/plugin-blea-hydrao/11622/36
