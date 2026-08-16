// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the LICENSE file.

import spi

import lora
import lora.sx1262
import lora.sx127x

import .configuration as configuration

/** Owns a radio and all transport resources used by it. */
class OpenedRadio:
  radio/lora.Radio
  bus_/spi.Bus
  device_/spi.Device
  closed_/bool := false

  constructor .radio .bus_ .device_:

  /** Closes the radio, SPI device, and SPI bus. */
  close -> none:
    if closed_: return
    closed_ = true
    radio.close
    device_.close
    bus_.close

/** Opens the radio described by $config. */
open config/Map -> OpenedRadio:
  family := configuration.required-string config "radio"
  if family == "sx1262": return open-sx1262_ config
  if family == "sx127x": return open-sx127x_ config
  throw "LORA_UNKNOWN_RADIO"

open-sx1262_ config/Map -> OpenedRadio:
  bus := open-bus_ config
  device/spi.Device? := null
  radio/lora.Radio? := null
  succeeded := false
  try:
    device = open-device_ bus config
    busy := configuration.required-int config "busy"
    reset := configuration.optional-nullable-int config "reset"
    dio1 := configuration.required-int config "dio1"
    tcxo-voltage := configuration.optional-int config "tcxo-voltage" 0
    dio2-rf-switch := configuration.optional-bool
        config
        "dio2-rf-switch"
        false
    radio = sx1262.Sx1262 device busy
        --reset=reset
        --dio1=dio1
        --tcxo-voltage=tcxo-voltage
        --dio2-rf-switch=dio2-rf-switch
    result := OpenedRadio radio bus device
    succeeded = true
    return result
  finally:
    if not succeeded:
      if radio: catch --trace: radio.close
      if device: device.close
      bus.close

open-sx127x_ config/Map -> OpenedRadio:
  bus := open-bus_ config
  device/spi.Device? := null
  radio/lora.Radio? := null
  succeeded := false
  try:
    device = open-device_ bus config
    reset := configuration.optional-nullable-int config "reset"
    dio0 := configuration.required-int config "dio0"
    radio = sx127x.Sx127x device --reset=reset --dio0=dio0
    result := OpenedRadio radio bus device
    succeeded = true
    return result
  finally:
    if not succeeded:
      if radio: catch --trace: radio.close
      if device: device.close
      bus.close

open-bus_ config/Map -> spi.Bus:
  return spi.Bus
      --clock=(configuration.required-int config "spi-clock")
      --mosi=(configuration.required-int config "spi-mosi")
      --miso=(configuration.required-int config "spi-miso")

open-device_ bus/spi.Bus config/Map -> spi.Device:
  return bus.device
      --cs=(configuration.required-int config "spi-cs")
      --frequency=(configuration.optional-int config "spi-frequency" 4_000_000)
