// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the examples/LICENSE file.

import gpio
import spi

import lora
import lora.sx1262

main:
  bus := spi.Bus --clock=9 --mosi=10 --miso=11
  device := bus.device --cs=8 --frequency=4_000_000
  busy := gpio.Pin 13
  reset := gpio.Pin 12
  dio1 := gpio.Pin 14
  radio := sx1262.Sx1262 device busy
      --reset=reset
      --dio1=dio1
      --tcxo-voltage=1_800
      --dio2-rf-switch
  try:
    radio.configure (lora.Configuration --frequency=868_100_000)
    print "HELTEC_RX_WAIT"
    packet := radio.receive --timeout-ms=10_000
    if packet:
      print "HELTEC_RX $(packet.payload.to-string) RSSI=$(packet.rssi) SNR=$(packet.snr)"
    else:
      print "HELTEC_RX_TIMEOUT"
  finally:
    radio.close
    dio1.close
    reset.close
    busy.close
    device.close
    bus.close
