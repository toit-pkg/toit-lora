// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the LICENSE file.

import gpio
import spi

import lora
import lora.sx1262
import lora.sx127x

/** Owns a board's radio and all transport resources used by it. */
class OpenedRadio:
  radio/lora.Radio
  bus_/spi.Bus
  device_/spi.Device
  pins_/List
  closed_/bool := false

  constructor .radio .bus_ .device_ .pins_:

  /** Closes the radio, pins, SPI device, and SPI bus. */
  close -> none:
    if closed_: return
    closed_ = true
    radio.close
    pins_.do: it.close
    device_.close
    bus_.close

/** Opens the radio on the named supported $board. */
open board/string -> OpenedRadio:
  if board == "heltec": return open-heltec_
  if board == "lilygo": return open-lilygo_
  throw "LORA_UNKNOWN_BOARD"

open-heltec_ -> OpenedRadio:
  bus := spi.Bus --clock=9 --mosi=10 --miso=11
  device/spi.Device? := null
  busy/gpio.Pin? := null
  reset/gpio.Pin? := null
  dio1/gpio.Pin? := null
  radio/lora.Radio? := null
  succeeded := false
  try:
    device = bus.device --cs=8 --frequency=4_000_000
    busy = gpio.Pin 13
    reset = gpio.Pin 12
    dio1 = gpio.Pin 14
    radio = sx1262.Sx1262 device busy
        --reset=reset
        --dio1=dio1
        --tcxo-voltage=1_800
        --dio2-rf-switch
    result := OpenedRadio radio bus device [dio1, reset, busy]
    succeeded = true
    return result
  finally:
    if not succeeded:
      if radio: catch --trace: radio.close
      if dio1: dio1.close
      if reset: reset.close
      if busy: busy.close
      if device: device.close
      bus.close

open-lilygo_ -> OpenedRadio:
  bus := spi.Bus --clock=5 --mosi=27 --miso=19
  device/spi.Device? := null
  reset/gpio.Pin? := null
  dio0/gpio.Pin? := null
  radio/lora.Radio? := null
  succeeded := false
  try:
    device = bus.device --cs=18 --frequency=4_000_000
    reset = gpio.Pin 23
    dio0 = gpio.Pin 26
    radio = sx127x.Sx127x device --reset=reset --dio0=dio0
    result := OpenedRadio radio bus device [dio0, reset]
    succeeded = true
    return result
  finally:
    if not succeeded:
      if radio: catch --trace: radio.close
      if dio0: dio0.close
      if reset: reset.close
      if device: device.close
      bus.close
