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
  if not args.is-empty: throw "Configure LoRaWAN using container assets"
  config := configuration.load
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

  opened := hardware.open config
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

region-from-string_ name/string -> region.Region:
  if name == "eu868": return region.Eu868
  if name == "us915": return region.Us915
  throw "LORAWAN_UNKNOWN_REGION"
