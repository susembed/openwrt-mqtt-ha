#!/bin/sh

# MQTT broker details
MQTT_BROKER="10.0.0.3"
MQTT_PORT="1883"
MQTT_USER="test"
MQTT_PASSWORD="test"

UPDATE_INTERVAL=10
EXPIRE=20
ENABLE_ATTRIBUTES=true
DEBUG=false

# Check for debug argument
if [ "$1" = "debug" ]; then
    DEBUG=true
fi

DEVICE_UID=$(cat /sys/class/net/br-lan/address | tr -d ':')
SYSTEM_BOARD=$(ubus call system board)

DEVICE_NAME=$(echo $SYSTEM_BOARD | jsonfilter -e '@.hostname')
DISCOVERY_DEVICE_TOPIC_PREFIX="homeassistant/device/${DEVICE_UID}/config"
MQTT_STATE_TOPIC_PREFIX="system_monitoring/${DEVICE_NAME}/state"
ONE_TIME_MQTT_STATE_TOPIC_PREFIX="system_monitoring/${DEVICE_NAME}/onetime-state"

# Get wired interfaces
# wired_interfaces=$(ls /sys/class/net | grep -vE '^(lo|br-.*|eth0|phy.*|ext_net)$')
wired_interfaces="wan lan1 lan2"
bandwidth_wired_interfaces=$(ls /sys/class/net | grep -vE '^(lo|br-.*|eth0|phy.*)$')
wlan_interfaces=$(ls /sys/class/net | grep -E '^(phy.*)$')
tx=""     # Create an empty string
rx=""
wlan_tx=0
wlan_rx=0
# Get initial values for bandwidth calculation. These strings always have the same length as the number of bandwidth_wired_interfaces
# Required restart of the script if the number of interfaces changes
i=0
for iface in $bandwidth_wired_interfaces; do
    if [ -f /sys/class/net/$iface/statistics/tx_bytes ]; then
        tx="$tx 0"
        rx="$rx 0"
        i=$((i + 1))
    fi
done

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
  "name": "${iface} Link Status",
  "icon":"mdi:ethernet",
  "expire_after": ${EXPIRE},
  "state_topic":"${MQTT_STATE_TOPIC_PREFIX}",
  "value_template":"{{'ON' if (value_json.${iface}_attr.speed |float(0) > 0) else 'OFF' }}",
  "attributes_topic":"${MQTT_STATE_TOPIC_PREFIX}",
  "attributes_template":"{{ value_json.${iface}_attr | tojson }}",
  "entity_category":"diagnostic",
  "unique_id":"${DEVICE_UID}_${iface}_link_status"
},
EOF
)
    fi
  done

  bandwidth_wired_interfaces_config=""
  for iface in $bandwidth_wired_interfaces; do
    if [ -f /sys/class/net/$iface/speed ]; then
      bandwidth_wired_interfaces_config=$(cat <<EOF
$bandwidth_wired_interfaces_config
"${DEVICE_UID}_${iface}_rx": {
  "p": "sensor",
  "name": "${iface} Rx Bandwidth",
  "icon":"mdi:download",
  "expire_after": ${EXPIRE},
  "unit_of_measurement":"Mbps",
  "state_topic":"${MQTT_STATE_TOPIC_PREFIX}",
  "value_template":"{{ value_json.${iface}_rx_speed |float(0) / 1000}}",
  "entity_category":"diagnostic",
  "unique_id":"${DEVICE_UID}_${iface}_rx"
},
"${DEVICE_UID}_${iface}_tx": {
  "p": "sensor",
  "name": "${iface} Tx Bandwidth",
  "icon":"mdi:upload",
  "expire_after": ${EXPIRE},
  "unit_of_measurement":"Mbps",
  "state_topic":"${MQTT_STATE_TOPIC_PREFIX}",
  "value_template":"{{ value_json.${iface}_tx_speed |float(0) / 1000}}",
  "entity_category":"diagnostic",
  "unique_id":"${DEVICE_UID}_${iface}_tx"
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
      "expire_after": ${EXPIRE},
      "unit_of_measurement":"%",
      "state_topic":"${MQTT_STATE_TOPIC_PREFIX}",
      "value_template":"{{ value_json.cpu_load|float(0) * 100 / $(cat /proc/cpuinfo | grep processor | wc -l) |round(1)}}",
      "json_attributes_topic":"${MQTT_STATE_TOPIC_PREFIX}",
      "json_attributes_template": "{{ value_json.cpu_load_attr | tojson }}",
      "entity_category":"diagnostic",
      "unique_id":"${DEVICE_UID}_cpu_load"
    },
    "${DEVICE_UID}_memory_usage": {
      "p": "sensor",
      "name": "Memory Usage",
      "icon":"mdi:memory",
      "expire_after": ${EXPIRE},
      "unit_of_measurement":"%",
      "state_topic":"${MQTT_STATE_TOPIC_PREFIX}",
      "value_template":"{{ value_json.memory_usage|float(0) |round(1)}}",
      "json_attributes_topic":"${MQTT_STATE_TOPIC_PREFIX}",
      "json_attributes_template": "{{ value_json.memory_attr | tojson }}",
      "entity_category":"diagnostic",
      "unique_id":"${DEVICE_UID}_memory_usage"
    },
    $wired_interfaces_config
    $bandwidth_wired_interfaces_config
    "${DEVICE_UID}_wlan_tx": {
      "p": "sensor",
      "name": "WLAN Tx Bandwidth",
      "icon":"mdi:upload",
      "expire_after": ${EXPIRE},
      "unit_of_measurement":"Mbps",
      "state_topic":"${MQTT_STATE_TOPIC_PREFIX}",
      "value_template":"{{ value_json.wlan_tx_speed |int(0) / 1000}}",
      "entity_category":"diagnostic",
      "unique_id":"${DEVICE_UID}_wlan_tx"

    },
    "${DEVICE_UID}_wlan_rx": {
      "p": "sensor",
      "name": "WLAN Rx Bandwidth",
      "icon":"mdi:download",
      "expire_after": ${EXPIRE},
      "unit_of_measurement":"Mbps",
      "state_topic":"${MQTT_STATE_TOPIC_PREFIX}",
      "value_template":"{{ value_json.wlan_rx_speed |int(0) / 1000}}",
      "entity_category":"diagnostic",
      "unique_id":"${DEVICE_UID}_wlan_rx"
    },
    "${DEVICE_UID}_last_boot": {
      "p": "sensor",
      "name": "Last Boot",
      "icon":"mdi:clock",
      "state_topic":"${ONE_TIME_MQTT_STATE_TOPIC_PREFIX}",
      "value_template":"{{now() - timedelta( seconds = value_json.uptime |int(0))}}",
      "entity_category":"diagnostic",
      "unique_id":"${DEVICE_UID}_last_boot"
    }
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
# Get wired interfaces link status
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
  done
# Calculate wired interfaces bandwidth
  i=0
  for iface in $bandwidth_wired_interfaces; do
    if [ -f /sys/class/net/$iface/statistics/rx_bytes ]; then
      rx_array=$(echo $rx | cut -d' ' -f$((i + 1)))
      tx_array=$(echo $tx | cut -d' ' -f$((i + 1)))

      if [ "$rx_array" -ne 0 ]; then
        rx_speed=$(cat /sys/class/net/$iface/statistics/rx_bytes)
        rx_speed=$((rx_speed - rx_array))
        if [ $rx_speed -lt 0 ]; then
          rx_speed=0
        fi
      else
        rx_speed=0
      fi
      rx=$(echo $rx | sed "s/\b$rx_array\b/$(cat /sys/class/net/$iface/statistics/rx_bytes)/")

      if [ "$tx_array" -ne 0 ]; then
        tx_speed=$(cat /sys/class/net/$iface/statistics/tx_bytes)
        tx_speed=$((tx_speed - tx_array))
        if [ $tx_speed -lt 0 ]; then
          tx_speed=0
        fi
      else
        tx_speed=0
      fi
      tx=$(echo $tx | sed "s/\b$tx_array\b/$(cat /sys/class/net/$iface/statistics/tx_bytes)/")

      data_payload=$(cat <<EOF
$data_payload
"${iface}_rx_speed": $(((rx_speed * 8) /1000 / $UPDATE_INTERVAL)),
"${iface}_tx_speed": $(((tx_speed * 8) /1000 / $UPDATE_INTERVAL)),
EOF
)
    fi
    i=$((i + 1))
  done
# Calculate WLAN bandwidth
new_wlan_rx=0
new_wlan_tx=0
  for iface in $wlan_interfaces; do
    if [ -f /sys/class/net/$iface/statistics/rx_bytes ]; then
        new_wlan_rx=$((new_wlan_rx + $(cat /sys/class/net/$iface/statistics/rx_bytes)))
        new_wlan_tx=$((new_wlan_tx + $(cat /sys/class/net/$iface/statistics/tx_bytes)))
      fi
  done
  if [ $wlan_rx -eq 0 ]; then
    wlan_rx_speed=0
    wlan_tx_speed=0
  else
    wlan_rx_speed=$((new_wlan_rx - wlan_rx))
    wlan_tx_speed=$((new_wlan_tx - wlan_tx))
    # Check for negative values when an interface is restarted
    if [ $wlan_rx_speed -lt 0 ]; then
      wlan_rx_speed=0
    fi
    if [ $wlan_tx_speed -lt 0 ]; then
      wlan_tx_speed=0
    fi
  fi
  wlan_rx=$new_wlan_rx
  wlan_tx=$new_wlan_tx


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
  data_payload=$(cat <<EOF
$data_payload
$attrs
"wlan_rx_speed": $(((wlan_rx_speed * 8) /1000 / $UPDATE_INTERVAL)),
"wlan_tx_speed": $(((wlan_tx_speed * 8) /1000 / $UPDATE_INTERVAL))
EOF
)

  data_payload=$(cat <<EOF
$data_payload
}
EOF
)
  if [ "$DEBUG" = true ]; then
      echo "Sensor Data Payload:"
      echo "$data_payload"
  else
      mosquitto_pub -h "$MQTT_BROKER" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASSWORD" -t "${MQTT_STATE_TOPIC_PREFIX}" -m "$data_payload"
  fi
}
publish_one_time_sensor_data() {
  uptime=$(cat /proc/uptime | awk '{print $1}')
  data_payload=$(cat <<EOF
{"uptime": $uptime}
EOF
)
  if [ "$DEBUG" = true ]; then
    echo "One Time Sensor Data Payload:"
    echo "$data_payload"
  else
    mosquitto_pub -h "$MQTT_BROKER" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASSWORD" -t "${ONE_TIME_MQTT_STATE_TOPIC_PREFIX}" -m "$data_payload"
  fi

}

publish_device_discovery_message
publish_one_time_sensor_data
# Main loop
while true; do
    publish_sensor_data
    sleep $UPDATE_INTERVAL
done