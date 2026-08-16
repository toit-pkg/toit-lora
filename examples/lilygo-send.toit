// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the examples/LICENSE file.

import spi

import lora
import lora.sx127x

/**
Sends one 868.1 MHz LoRa packet from a LILYGO T3 LoRa32 V1.6.

The example uses the board's ESP32/SX1276 pin mapping and prints a marker after
  transmitting the payload.
*/
main:
  bus := spi.Bus --clock=5 --mosi=27 --miso=19
  device := bus.device --cs=18 --frequency=4_000_000
  radio := sx127x.Sx127x device --reset=23 --dio0=26
  try:
    configuration := lora.Configuration
    radio.configure configuration
    sleep --ms=2_000
    print "LILYGO_TX"
    radio.transmit "hello-from-lilygo".to-byte-array
  finally:
    radio.close
    device.close
    bus.close
