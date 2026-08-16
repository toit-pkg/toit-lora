// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the examples/LICENSE file.

import spi

import lora
import lora.sx127x

/**
Receives one 868.1 MHz LoRa packet on a LILYGO T3 LoRa32 V1.6 and replies.

The example uses the board's ESP32/SX1276 pin mapping, prints the received
  payload and link quality, and transmits a pong response.
*/
main:
  bus := spi.Bus --clock=5 --mosi=27 --miso=19
  device := bus.device --cs=18 --frequency=4_000_000
  radio := sx127x.Sx127x device --reset=23 --dio0=26
  try:
    configuration := lora.Configuration
    radio.configure configuration
    print "LILYGO_RX_WAIT"
    packet := radio.receive --timeout-ms=15_000
    if packet:
      print "LILYGO_RX $(packet.payload.to-string) RSSI=$(packet.rssi) SNR=$(packet.snr)"
      sleep --ms=250
      radio.transmit "pong-from-lilygo".to-byte-array
      print "LILYGO_TX"
    else:
      print "LILYGO_RX_TIMEOUT"
  finally:
    radio.close
    device.close
    bus.close
