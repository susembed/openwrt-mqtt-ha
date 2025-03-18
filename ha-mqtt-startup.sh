#!/bin/sh /etc/rc.common
# Required packages: mosquitto-client
# Required files: /etc/custom_script/ha-mqtt.sh
# Put this file in /etc/init.d/
# chmod +x /etc/init.d/ha-mqtt-startup.sh
# /etc/init.d/ha-mqtt-startup.sh enable
# /etc/init.d/ha-mqtt-startup.sh start
START=99
STOP=10

start() {
    echo "Starting push MQTT sensor data to Home Assistant"
    /bin/ash /etc/custom_script/ha-mqtt.sh &
}

stop() {
    echo "Stopping push MQTT sensor data to Home Assistant"
    kill -9  $(ps | grep '/etc/custom_script/ha-mqtt.sh' | grep -v 'grep' | awk '{print $1}');
}

