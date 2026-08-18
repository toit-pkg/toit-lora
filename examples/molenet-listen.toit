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
    packet/lora.Packet? := null
    timed-out := catch --unwind=(: it != DEADLINE-EXCEEDED-ERROR):
      with-timeout --ms=10_000: packet = radio.receive
    if timed-out:
      print "MOLENET_RX_TIMEOUT"
    else:
      print "MOLENET_RX $(packet.payload.to-string) RSSI=$(packet.rssi) SNR=$(packet.snr)"
  finally:
    radio.close
    device.close
    bus.close
