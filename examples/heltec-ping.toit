// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the examples/LICENSE file.

import spi

import lora
import lora.sx1262

/**
Sends one 868.1 MHz LoRa ping from a Heltec WiFi LoRa 32 V3 and waits for a
  reply.

The example uses the board's ESP32-S3/SX1262 pin mapping and prints the reply's
  payload and link quality, or a timeout after five seconds.
*/
main:
  bus := spi.Bus --clock=9 --mosi=10 --miso=11
  device := bus.device --cs=8 --frequency=4_000_000
  radio := sx1262.Sx1262 device 13
      --reset=12
      --dio1=14
      --tcxo-voltage=1_800
      --dio2-rf-switch
  try:
    configuration := lora.Configuration
    radio.configure configuration
    print "HELTEC_TX"
    radio.transmit "ping-from-heltec".to-byte-array
    packet := radio.receive --timeout-ms=5_000
    if packet:
      print "HELTEC_RX $(packet.payload.to-string) RSSI=$(packet.rssi) SNR=$(packet.snr)"
    else:
      print "HELTEC_RX_TIMEOUT"
  finally:
    radio.close
    device.close
    bus.close
