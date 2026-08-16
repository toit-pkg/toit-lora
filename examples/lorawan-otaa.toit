// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the examples/LICENSE file.

import encoding.hex as hex
import encoding.tison
import spi
import system.assets

import lora
import lora.sx1262
import lora.sx127x
import lora.lorawan.device
import lora.lorawan.region

/**
Joins The Things Stack over OTAA and sends one LoRaWAN uplink.

The `board` Jaguar define selects a LILYGO T3 LoRa32 V1.6, Heltec WiFi LoRa 32
  V3, or MoleNet v7.1. The remaining defines provide OTAA credentials and the
  optional EU868 data rate.
*/
main:
  configuration := assets.decode.get "jag.defines"
      --if-present=: tison.decode it
      --if-absent=: {:}
  if configuration is not Map: throw "LORAWAN_INVALID_CONFIGURATION"
  board := required-string_ configuration "board"
  if board == "lilygo":
    run-lilygo_ configuration
  else if board == "heltec":
    run-heltec_ configuration
  else if board == "molenet":
    run-molenet_ configuration
  else:
    throw "LORAWAN_UNKNOWN_BOARD"

run-lilygo_ configuration/Map -> none:
  bus := spi.Bus --clock=5 --mosi=27 --miso=19
  device := bus.device --cs=18 --frequency=4_000_000
  try:
    radio := sx127x.Sx127x device --reset=23 --dio0=26
    try:
      join-and-send_ radio configuration
    finally:
      radio.close
  finally:
    device.close
    bus.close

run-heltec_ configuration/Map -> none:
  bus := spi.Bus --clock=9 --mosi=10 --miso=11
  device := bus.device --cs=8 --frequency=4_000_000
  try:
    radio := sx1262.Sx1262 device 13
        --reset=12
        --dio1=14
        --tcxo-voltage=1_800
        --dio2-rf-switch
    try:
      join-and-send_ radio configuration
    finally:
      radio.close
  finally:
    device.close
    bus.close

run-molenet_ configuration/Map -> none:
  bus := spi.Bus --clock=14 --mosi=47 --miso=21
  device := bus.device --cs=48 --frequency=4_000_000
  try:
    radio := sx1262.Sx1262 device 39
        --reset=15
        --dio1=46
        --dio2-rf-switch
    try:
      join-and-send_ radio configuration
    finally:
      radio.close
  finally:
    device.close
    bus.close

join-and-send_ radio/lora.Radio configuration/Map -> none:
  application-key := hex.decode (required-string_ configuration "app-key")
  join-eui := hex.decode (required-string_ configuration "join-eui")
  device-eui := hex.decode (required-string_ configuration "device-eui")
  device-nonce := required-int_ configuration "device-nonce"
  configured-data-rate := configuration.get "data-rate"
  data-rate := configured-data-rate is int ? configured-data-rate : 0
  end-device := device.ClassA
      --radio=radio
      --region=region.Eu868
      --data-rate=data-rate
  print "OTAA_JOIN_REQUEST nonce=$device-nonce"
  session := end-device.join
      --application-key=application-key
      --join-eui=join-eui
      --device-eui=device-eui
      --device-nonce=device-nonce
  if not session:
    print "OTAA_JOIN_TIMEOUT"
    return
  print "OTAA_JOINED address=$session.device-address"
  downlink := end-device.send "hello-from-toit"
  print "OTAA_UPLINK_SENT"
  if downlink:
    print "OTAA_DOWNLINK port=$downlink.port bytes=$downlink.payload.size"

required-string_ configuration/Map key/string -> string:
  value := configuration.get key
  if value is not string: throw "LORAWAN_MISSING_CONFIGURATION_$key"
  return value

required-int_ configuration/Map key/string -> int:
  value := configuration.get key
  if value is int: return value
  if value is string: return int.parse value
  throw "LORAWAN_MISSING_CONFIGURATION_$key"
