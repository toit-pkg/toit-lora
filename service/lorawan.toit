// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the LICENSE file.

import encoding.hex as hex

import lorawan.device
import lorawan.providers.end-device as provider
import lorawan.providers.flash-state
import lorawan.region

import .configuration as configuration
import .hardware as hardware
import .lorawan-radio-adapter as adapter

main args/List:
  config := args.is-empty
      ? configuration.load
      : configuration-from-args_ args
  board := configuration.required-string config "board"
  application-key := hex.decode
      configuration.required-string config "app-key"
  join-eui := hex.decode
      configuration.required-string config "join-eui"
  device-eui-text := configuration.required-string config "device-eui"
  device-eui := hex.decode device-eui-text
  regional-plan := region-from-string_
      configuration.required-string config "region"
  data-rate := configuration.optional-int config "data-rate" 0
  tx-power := configuration.optional-int config "tx-power" 14
  receive-window-ms := configuration.optional-int
      config
      "receive-window-ms"
      1_000
  initial-device-nonce := configuration.optional-int
      config
      "initial-device-nonce"
      0
  storage-path := configuration.optional-string
      config
      "storage-path"
      "toit.io/lorawan/$device-eui-text"

  opened := hardware.open board
  state := flash-state.FlashStateStore storage-path
      --initial-device-nonce=initial-device-nonce
  class-a := device.ClassA
      (adapter.LorawanRadioAdapter opened.radio)
      regional-plan
      --data-rate=data-rate
      --tx-power=tx-power
      --receive-window-ms=receive-window-ms
  credentials := provider.OtaaCredentials application-key join-eui device-eui
  installed := provider.install class-a state --credentials=credentials
  try:
    while true: sleep --ms=60_000
  finally:
    installed.uninstall
    state.close
    opened.close

configuration-from-args_ args/List -> Map:
  if args.size != 5 and args.size != 6:
    throw "Usage: lorawan <board> <region> <app-key> <join-eui> <device-eui> [device-nonce]"
  result := {
    "board": args[0],
    "region": args[1],
    "app-key": args[2],
    "join-eui": args[3],
    "device-eui": args[4],
  }
  if args.size == 6: result["initial-device-nonce"] = int.parse args[5]
  return result

region-from-string_ name/string -> region.Region:
  if name == "eu868": return region.Eu868
  if name == "us915": return region.Us915
  throw "LORAWAN_UNKNOWN_REGION"
