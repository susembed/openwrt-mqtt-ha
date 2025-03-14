# openwrt-mqtt-ha
Monitor system resource of OpenWrt router from Home Assistant over MQTT. 

Script runs on the router and push sensor's data to MQTT broker.

Goal: a simple, light-weight, low-dependency script 
### Requirements
- MQTT broker
- Home Assitant core with configured MQTT broker integration
### Script dependencies
- mosquitto-client-nossl package, can be installed with command: `opkg install mosquitto-client-nossl`
