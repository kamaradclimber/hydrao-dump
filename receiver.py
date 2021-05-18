import sys
import time
from argparse import ArgumentParser

from bluepy import btle
from colr import color as colr

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
    while True:
        try:
            connect_and_read()
        except btle.BTLEDisconnectError as e:
            print("Got disconnected, will retry")
            time.sleep(1)



def connect_and_read():
    # get args
    args = get_args()

    print("Connecting...")
    hydrao = btle.Peripheral(args.mac_address)
    print("Connected")
    # print_peripheral(hydrao)

    so_called_battery_service_uuid = "0000180f-0000-1000-8000-00805f9b34fb"
    battery_service = hydrao.getServiceByUUID(so_called_battery_service_uuid)

    ca31 = "0000ca31-0000-1000-8000-00805f9b34fb"
    ca32 = "0000ca32-0000-1000-8000-00805f9b34fb"
    ca27 = "0000ca27-0000-1000-8000-00805f9b34fb"
    current_volumes = "0000ca1c-0000-1000-8000-00805f9b34fb"

    while True:
        now = time.asctime(time.gmtime())
        volumes_string = battery_service.getCharacteristics(current_volumes)[0].read()
        print(f"{now} current_volume: {get_volumes(volumes_string)}")
        ca32_value_string = battery_service.getCharacteristics(ca32)[0].read()
        print(f"{now} ca32: {ca32_value_string}")
        print_unknown(ca32_value_string)
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
