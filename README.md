# openwrt-mqtt-ha
Monitor system resource of OpenWrt router from Home Assistant over MQTT. 

Script runs on the router and push sensor's data to MQTT broker.

Goal: a simple, light-weight, low-dependency script 
Challenge: lack of resources (CPU, mem, disk), very limited `ash` shell enviroment
![Screenshot from 2025-04-10 00-17-56](https://github.com/user-attachments/assets/bf9b619a-68d0-484b-92b9-ce44f3c24f95)
Tested on Xiaomi Routers: 3G v1 and 3G v2
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
- Start script with Luci or `/etc/inint.d/ha-mqtt-startup.sh start`. Do similar to `enable` (start on boot) or `stop` script if you need.
- When script start, new device should appear in Home Assistant -> Setting -> Devices & services -> Integrations -> MQTT. Make sure you turn `Enable newly added entities` on in MQTT integration -> System options
#### Configuration
- Edit file: `vi /etc/custom_script/ha-mqtt.sh`
- Set your `MQTT_BROKER, MQTT_USER, MQTT_PASSWORD`
#### Debug
- If there is any problem, to debug yourself, you can stop script then run it from cmd `ash /ha-mqtt.sh` to see there is error spit out.
- Run ` ash ./ha-mqtt.sh debug` to print out all messages without publish to MQTT broker.
### Notes
- Script using lan MAC address as `DEVICE_UID`, host name as `DEVICE_NAME`
- By default, script push data each `UPDATE_INTERVAL=10` seconds. `EXPIRE=20` mean if no data is push after 20s, sensors will be set to `unavailable` state in Home Assistant.
- `DISCOVERY_DEVICE_TOPIC_PREFIX` is `homeassistant/device/${DEVICE_UID}/config` and `ONE_TIME_MQTT_STATE_TOPIC_PREFIX` is `system_monitoring/${DEVICE_NAME}/onetime-state`, those only push message one time when script start.

- `wired_interfaces` used for detect devices interfaces's link status. Usually, those are real interfaces which connectd to CPU. Currently, I'm not working on link status for switch yet.
- `bandwidth_interfaces` are list of interfaces will be create sensor for bandwidth. It shoud be real interfaces and VPN interfaces.
- Bandwidth of wifi is combine from all wlan interfaces and SSIDs (phy0-ap0, phy1-ap0 ...).
- CPU load is calculate from load_1m*100/CPU_thread. This is not accurate and need a new proper method.
- 
