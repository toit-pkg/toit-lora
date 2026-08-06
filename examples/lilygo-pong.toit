// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the examples/LICENSE file.

import gpio
import spi

import lora
import lora.sx127x

main:
  bus := spi.Bus --clock=5 --mosi=27 --miso=19
  device := bus.device --cs=18 --frequency=4_000_000
  reset := gpio.Pin 23
  dio0 := gpio.Pin 26
  radio := sx127x.Sx127x device --reset=reset --dio0=dio0
  try:
    radio.configure (lora.Configuration
        --frequency=868_100_000
        --bandwidth=125_000
        --spreading-factor=7
        --coding-rate=5
        --crc
        --tx-power=14)
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
    dio0.close
    reset.close
    device.close
    bus.close
