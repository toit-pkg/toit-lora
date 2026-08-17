// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the examples/LICENSE file.

import i2c

import bme280
import lora.lorawan.end-device

/**
Reads the MoleNet v7.1 BME280 and sends signed centi-degrees Celsius on port 1.

The two-byte payload is big-endian. For example, `#[0x09, 0xc4]` represents
25.00 degrees Celsius, while `#[0xff, 0x9c]` represents -1.00 degree Celsius.
*/
main:
  temperature := read-temperature_
  centi-degrees := (temperature * 100.0).round
  payload := ByteArray 2
  payload[0] = (centi-degrees >> 8) & 0xff
  payload[1] = centi-degrees & 0xff

  device := end-device.v1
  try:
    if not device.activated and not device.join:
      print "BME280_LORAWAN_JOIN_TIMEOUT"
      return
    device.send payload --port=1
    print "BME280_TEMPERATURE_C=$temperature"
    print "BME280_LORAWAN_SENT_CENTI_DEGREES=$centi-degrees"
  finally:
    device.close

read-temperature_ -> float:
  bus := i2c.Bus --sda=9 --scl=8
  device := bus.device bme280.I2C-ADDRESS
  sensor/bme280.Driver? := null
  try:
    sensor = bme280.Driver device
    return sensor.read-temperature
  finally:
    if sensor: sensor.close
    device.close
    bus.close
