// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the examples/LICENSE file.

import spi

import lora
import lora.sx1262

/**
Listens for one 868.1 MHz LoRa packet on a MoleNet v7.1.

The example uses the board's ESP32-S3/SX1262 pin mapping and prints the
  received payload and link quality, or a timeout after ten seconds.
*/
main:
  bus := spi.Bus --clock=14 --mosi=47 --miso=21
  device := bus.device --cs=48 --frequency=4_000_000
  radio := sx1262.Sx1262 device 39
      --reset=15
      --dio1=46
      --dio2-rf-switch
  try:
    configuration := lora.Configuration
    radio.configure configuration
    print "MOLENET_RX_WAIT"
    packet := radio.receive --timeout-ms=10_000
    if packet:
      print "MOLENET_RX $(packet.payload.to-string) RSSI=$(packet.rssi) SNR=$(packet.snr)"
    else:
      print "MOLENET_RX_TIMEOUT"
  finally:
    radio.close
    device.close
    bus.close
