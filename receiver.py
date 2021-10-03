import time
from argparse import ArgumentParser
import os
import json

from bluepy import btle
import paho.mqtt.client as mqtt

# Credits: https://itnext.io/ble-and-gatt-for-iot-2ae658baafd5

def print_peripheral(peripheral):
    print("Discovering Services...")
    services = peripheral.getServices()  # a first discovery is necessary apparently
    for service in services:
        print(f"{service} (uuid {service.uuid})")
        for characteristic in service.getCharacteristics():
            print(f"  {characteristic}")
            print(f"    Characteristic id {characteristic.getHandle()}, uuid {characteristic.uuid}. Properties: {characteristic.propertiesToString()}")
            if characteristic.supportsRead():
                print(f"    Value: {characteristic.read()}")

def main():
    mqtt_client = build_mqtt_client()
    while True:
        try:
            print("connect and read")
            connect_and_read(mqtt_client)
        except btle.BTLEDisconnectError as e:
            print("Got disconnected, will retry", flush=True)
            time.sleep(1)

def build_mqtt_client():
    client = mqtt.Client()
    host = os.getenv('MQTT_HOST', 'localhost')
    port = int(os.getenv('MQTT_PORT', '1883'))
    user = os.getenv('MQTT_USER', None)
    password = os.getenv('MQTT_PASSWORD', None)
    client.enable_logger()  # TODO(g.seux): disable atfer a while

    if user is not None and password is not None:
        client.username_pw_set(user, password)
    client.connect(host, port, 60)
    client.loop_start()
    return client

def mqtt_declare_hydrao_sensors(mqtt_client, hydrao, delete_first=False):
    """
    Declare hydrao sensors in home assistant.
    According to documentation, one can declare multiple sensors sharing the same
    state_topic to allow to update all sensors in one message.
    For now, topics are completely hardcoded
    """
    prefix_topic = f"homeassistant/sensor/hydrao_{hydrao.addr}"
    config_topic = f"{prefix_topic}/config"
    attributes_topic = f"{prefix_topic}/attributes"
    state_topic = f"{prefix_topic}/state"
    config = {"name": f"Hydrao shower head {hydrao.addr}", "state_class": "total_increasing", "device_class": "gas", "state_topic": state_topic, "unit_of_measurement": "L", "unique_id": hydrao.addr, "json_attributes_topic": attributes_topic }

    if delete_first:
        mqtt_client.publish(config_topic, '')

    mqtt_client.publish(config_topic, json.dumps(config))

def mqtt_update_hydrao_sensors(mqtt_client, current_volume, total_volume, hydrao):
    prefix_topic = f"homeassistant/sensor/hydrao_{hydrao.addr}"
    attributes_topic = f"{prefix_topic}/attributes"
    state_topic = f"{prefix_topic}/state"
    mqtt_client.publish(state_topic, current_volume)
    attributes = { "temperature": 42.42, "current_volume": current_volume, "last_400_showers": total_volume }
    mqtt_client.publish(attributes_topic, json.dumps(attributes))

def connect_and_read(mqtt_client=None):
    # get args
    args = get_args()

    print("Connecting...", flush=True)
    hydrao = btle.Peripheral(args.mac_address)
    print("Connected")
    # print_peripheral(hydrao)
    if mqtt_client is not None:
        mqtt_declare_hydrao_sensors(mqtt_client, hydrao)

    so_called_battery_service_uuid = "0000180f-0000-1000-8000-00805f9b34fb"
    battery_service = hydrao.getServiceByUUID(so_called_battery_service_uuid)

    ca31 = "0000ca31-0000-1000-8000-00805f9b34fb"
    ca32 = "0000ca32-0000-1000-8000-00805f9b34fb"
    ca27 = "0000ca27-0000-1000-8000-00805f9b34fb"
    current_volumes = "0000ca1c-0000-1000-8000-00805f9b34fb"

    while True:
        now = time.asctime(time.gmtime())
        total_volume, current_volume = get_volumes(battery_service.getCharacteristics(current_volumes)[0].read())
        print(f"{now} current_volume: {current_volume}L, total volume: {total_volume}L", flush=True)
        # ca32_value_string = battery_service.getCharacteristics(ca32)[0].read()
        # print(f"{now} ca32: {ca32_value_string}")
        # print_unknown(ca32_value_string)
        if mqtt_client is not None:
            mqtt_update_hydrao_sensors(mqtt_client, current_volume, total_volume, hydrao)
        time.sleep(2)

def print_unknown(string):
    # Take a hexstring of values as a series of bytes
    values = bytearray(string)
    full = int.from_bytes(values, byteorder="little")
    full_big = int.from_bytes(values, byteorder="big")
    beg = int.from_bytes(values[0:1], byteorder="little")
    end = int.from_bytes(values[2:3], byteorder="little")
    print(f"full {full}, full_big: {full_big}, beg {beg}, end {end}")


def get_volumes(volumes_string):
    # Return a tuple of (total_volume, current_shower_volume)
    # take a hexstring of int values as a series of bytes. Order is assumed little endian byte (but not sure)
    # e.g., b'\xd9\x03\x03\x00' -> bytearray(b'\xd9\x03\x03\x00') -> (217, 3)
    combined_value = bytearray(volumes_string)
    total_volume = int.from_bytes(combined_value[0:1], byteorder="little")
    current_shower_volume = int.from_bytes(combined_value[2:3], byteorder="little")
    return (total_volume, current_shower_volume)


def get_args():
    arg_parser = ArgumentParser(description="Hydrao shower head")
    arg_parser.add_argument('mac_address', help="MAC address of device to connect")
    args = arg_parser.parse_args()
    return args


if __name__ == "__main__":
    main()
