#!/bin/sh

# MQTT broker details
MQTT_BROKER="10.0.0.3"
MQTT_PORT="1883"
MQTT_USER="test"
MQTT_PASSWORD="test"

UPDATE_INTERVAL=10
ENABLE_ATTRIBUTES=true
DEBUG=false

# Check for debug argument
if [ "$1" = "debug" ]; then
    DEBUG=true
fi

DEVICE_UID=$(cat /sys/class/net/br-lan/address | tr -d ':')
SYSTEM_BOARD=$(ubus call system board)


# Get wired interfaces
wired_interfaces=$(ls /sys/class/net | grep -vE '^(lo|br-.*|wan|phy.*)$')

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
  wired_interfaces_config=""
    for iface in $wired_interfaces; do
        if [ -f /sys/class/net/$iface/speed ]; then
            wired_interfaces_config=$(cat <<EOF
$wired_interfaces_config
"${DEVICE_UID}_${iface}_link_status": {
  "p": "binary_sensor",
  "name": "${DEVICE_NAME} ${iface} Link Status",
  "icon":"mdi:ethernet",
  "expire_after": ${UPDATE_INTERVAL * 2},
  "state_topic":"${MQTT_STATE_TOPIC_PREFIX}",
  "value_template":"{{ value_json.${iface}_attr.speed |float(0) > 0}}",
  "attributes_topic":"${MQTT_STATE_TOPIC_PREFIX}",
  "attributes_template":"{{ value_json.${iface}_attr | tojson }}",
  "entity_category":"connectivity",
  "unique_id":"${DEVICE_UID}_${iface}_link_status"
},
EOF
)
        fi
    done
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
      "expire_after": ${UPDATE_INTERVAL * 2},
      "unit_of_measurement":"%",
      "state_topic":"${MQTT_STATE_TOPIC_PREFIX}",
      "value_template":"{{ value_json.cpu_load|float(0) / $(cat /proc/cpuinfo | grep processor | wc -l)}}",
      "json_attributes_topic":"${MQTT_STATE_TOPIC_PREFIX}",
      "json_attributes_template": "{{ value_json.cpu_load_attr | tojson }}",
      "entity_category":"diagnostic",
      "unique_id":"${DEVICE_UID}_cpu_load"
    },
    "${DEVICE_UID}_memory_usage": {
      "p": "sensor",
      "name": "Memory Usage",
      "icon":"mdi:memory",
      "expire_after": ${UPDATE_INTERVAL * 2},
      "unit_of_measurement":"%",
      "state_topic":"${MQTT_STATE_TOPIC_PREFIX}",
      "value_template":"{{ value_json.memory_usage|float(0)}}",
      "json_attributes_topic":"${MQTT_STATE_TOPIC_PREFIX}",
      "json_attributes_template": "{{ value_json.memory_attr | tojson }}",
      "entity_category":"diagnostic",
      "unique_id":"${DEVICE_UID}_memory_usage"
    },
    $wired_interfaces_config
  },
  "qos": 0
}
EOF
)
    if [ "$DEBUG" = true ]; then
        echo "Device Discovery Payload:"
        echo "$payload"
    else
        mosquitto_pub -h "$MQTT_BROKER" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASSWORD" -t "${DISCOVERY_DEVICE_TOPIC_PREFIX}" -r -m "$payload" -r
    fi
}

publish_sensor_data() {
  loadavg=$(cat /proc/loadavg)
  memory=$(free | grep Mem )




  data_payload=$(cat <<EOF
{"cpu_load": $(echo $loadavg | awk '{print $1}'),
"memory_usage": $(echo $memory | awk '{print $3/$2*100}'),
EOF
)
  for iface in $wired_interfaces; do
    if [ -f /sys/class/net/$iface/speed ]; then
      speed=$(cat /sys/class/net/$iface/speed)
      data_payload=$(cat <<EOF
$data_payload
"${iface}_attr": {
  "speed": "$speed"
},
EOF
)
    fi
  if [ "$ENABLE_ATTRIBUTES" = true ]; then
    data_payload=$(cat <<EOF
$data_payload
"cpu_load_attr":{
"load5":$(echo $loadavg | awk '{print $2}'),
"load15": $(echo $loadavg | awk '{print $3}')
},
"memory_attr":{
"total": $(echo $memory | awk '{print $2}'),
"free": $(echo $memory | awk '{print $4}')
},
EOF
)
  else
    attrs=""
  fi
  done
    if [ "$DEBUG" = true ]; then
        echo "Sensor Data Payload:"
        echo "$data_payload"
    else
        mosquitto_pub -h "$MQTT_BROKER" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASSWORD" -t "${MQTT_STATE_TOPIC_PREFIX}" -m "$data_payload"
    fi
}

publish_device_discovery_message
# Main loop
while true; do
    publish_sensor_data
    sleep $UPDATE_INTERVAL
done