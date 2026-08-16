// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the examples/LICENSE file.

import encoding.hex
import encoding.tison
import spi
import system.assets

import lora
import lora.sx1262
import lora.sx127x

/**
Listens for one raw LoRaWAN uplink and prints its encrypted physical payload.

The `board` Jaguar define selects either a LILYGO T3 LoRa32 V1.6 or a Heltec
  WiFi LoRa 32 V3; `frequency` selects the channel to inspect.
*/
main:
  configuration := assets.decode.get "jag.defines"
      --if-present=: tison.decode it
      --if-absent=: {:}
  if configuration is not Map: throw "LORAWAN_INVALID_CONFIGURATION"
  board := configuration.get "board"
  frequency := configuration.get "frequency"
  if frequency is not int: throw "LORAWAN_INVALID_FREQUENCY"
  if board == "lilygo":
    run-lilygo_ frequency
  else if board == "heltec":
    run-heltec_ frequency
  else:
    throw "LORAWAN_UNKNOWN_BOARD"

run-lilygo_ frequency/int -> none:
  bus := spi.Bus --clock=5 --mosi=27 --miso=19
  device := bus.device --cs=18 --frequency=4_000_000
  try:
    radio := sx127x.Sx127x device --reset=23 --dio0=26
    try:
      sniff_ radio frequency
    finally:
      radio.close
  finally:
    device.close
    bus.close

run-heltec_ frequency/int -> none:
  bus := spi.Bus --clock=9 --mosi=10 --miso=11
  device := bus.device --cs=8 --frequency=4_000_000
  try:
    radio := sx1262.Sx1262 device 13
        --reset=12
        --dio1=14
        --tcxo-voltage=1_800
        --dio2-rf-switch
    try:
      sniff_ radio frequency
    finally:
      radio.close
  finally:
    device.close
    bus.close

sniff_ radio/lora.Radio frequency/int -> none:
  configuration := lora.Configuration
      --frequency=frequency
      --sync-word=lora.PUBLIC-SYNC-WORD
  radio.configure configuration
  print "LORAWAN_SNIFF_WAIT"
  packet := radio.receive --timeout-ms=60_000
  if packet:
    print "LORAWAN_SNIFF_RX $(hex.encode packet.payload)"
    print "LORAWAN_SNIFF_SIGNAL rssi=$(packet.rssi) snr=$(packet.snr)"
  else:
    print "LORAWAN_SNIFF_TIMEOUT"
