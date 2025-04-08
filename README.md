# openwrt-mqtt-ha
Monitor system resource of OpenWrt router from Home Assistant over MQTT. 

Script runs on the router and push sensor's data to MQTT broker.

Goal: a simple, light-weight, low-dependency script 
### Requirements
- MQTT broker
- Home Assitant core with configured MQTT broker integration
### Script dependencies
- mosquitto-client-nossl package, can be installed with command: `opkg install mosquitto-client-nossl`. It's also may work with ssl if you install ssl mqtt package.
### How to use
#### Install
- Download and put `ha-mqtt-startup.sh` into `/etc/init.d/`.
- Download and put `ha-mqtt.sh` into `/etc/custom-script/` folder (you may need create the folder first).
- Config as explains below
- Now you may see `ha-mqtt-startup.sh` in Luci -> System -> Startup. If not, refresh web page or reboot OpenWrt.
- Start script with Luci or `/etc/inint.d/ha-mqtt-startup.sh start`.
- Do similar to `enable` (start on boot) or `stop` script.
#### Configuration
- Edit file: `vi /etc/custom_script/ha-mqtt.sh`
- Set your `MQTT_BROKER, MQTT_USER, MQTT_PASSWORD`
#### Debug
- Run ` ash ./ha-mqtt.sh debug` to print out all messages without publish to MQTT broker
### Notes
- Script using lan MAC address as device'UID
- By default, script push data each `UPDATE_INTERVAL=10` seconds. `EXPIRE=20` mean if no data is push after 20s, sensors will be set to `unavailable` state in Home Assistant.
