#!/bin/bash

# MQTT broker details
MQTT_BROKER="10.0.0.3"
MQTT_PORT="1883"
MQTT_USER="test"
MQTT_PASSWORD="test"

DEVICE_UID=$(cat /sys/class/net/br-lan/address | tr -d ':')
SYSTEM_BOARD=$(ubus call system board)

DEVICE_NAME=$(echo $SYSTEM_BOARD | jsonfilter -e '@.hostname')
DEVICE_MODEL=$(echo $SYSTEM_BOARD | jsonfilter -e '@.model')
DEVICE_MANUFACTURER="OpenWRT"
DISCOVERY_DEVICE_TOPIC_PREFIX="homeassistant/device/${DEVICE_UID}/config"
MQTT_STATE_TOPIC_PREFIX="system_monitoring/${DEVICE_NAME}/state"

# ubus call system info | jsonfilter -e '@.memory.total'

hw_version=$(echo $SYSTEM_BOARD | jsonfilter -e '@.model' | grep -oE 'v[0-9]+(\.[0-9]+)*')
if [ -z "$hw_version" ]; then
    hw_version="v1"
fi

publish_device_discovery_message() {
    payload=$(cat <<EOF
{
  "dev": {
    "identifiers": "${DEVICE_UID}",
    "name": "${DEVICE_NAME}",
    "model": "$(echo $SYSTEM_BOARD | jsonfilter -e '@.model')",
    "manufacturer": "$(echo $SYSTEM_BOARD | jsonfilter -e '@.model' | awk '{print $1}')",
    "sw_version": "$(echo $SYSTEM_BOARD | jsonfilter -e '@.release.version')",
    "hw_version": "${hw_version}",
    "configuration_url": "https://$(ip addr show br-lan | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)/"
  
  },
  "o": {
    "name":"mqtt_openwrt_monitering_ha",
    "sw": "0.1"},
  "cmps": {
    "${DEVICE_UID}_cpu_load": {
      "p": "sensor",
      "name": "CPU load",
      "icon":"mdi:cpu-32-bit",
      "expriy_after": 60,
      "unit_of_measurement":"%",
      "state_topic":"${MQTT_STATE_TOPIC_PREFIX}",
      "value_template":"{{ value_json.cpu_load }}",
      "json_attributes_topic":"${MQTT_STATE_TOPIC_PREFIX}",
      "json_attributes_template": "{{ value_json.cpu_load_attr | tojson }}",
      "entity_category":"diagnostic",
      "unique_id":"${DEVICE_UID}_cpu_load"
    }
  },
  "qos": 0
}
EOF
)
    echo $payload
    mosquitto_pub -h "$MQTT_BROKER" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASSWORD" -t "${DISCOVERY_DEVICE_TOPIC_PREFIX}" -r -m "$payload" -r
}

# Publish CPU load
publish_cpu_load() {
    cpu_load=$(cat /proc/loadavg | awk '{print $1}')
    payload=$(cat <<EOF
{"cpu_load": ${cpu_load},"cpu_load_attr":{"load1":$(cat /proc/loadavg | awk '{print $1}'),"load5":$(cat /proc/loadavg | awk '{print $2}'),"load15": $(cat /proc/loadavg | awk '{print $3}')}}
EOF
)
    echo $payload
    mosquitto_pub -h "$MQTT_BROKER" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASSWORD" -t "${MQTT_STATE_TOPIC_PREFIX}" -m "$payload"
}

publish_device_discovery_message
# Main loop
while true; do
    publish_cpu_load
    sleep 60
done

