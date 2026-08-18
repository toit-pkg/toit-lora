// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the LICENSE file.

import encoding.hex as hex

import lora.lorawan.device
import lora.lorawan.providers.end-device as provider
import lora.lorawan.providers.flash-state
import lora.lorawan.region

import .configuration as configuration
import .hardware as hardware

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
  session-key := configuration.optional-string config "session-key" "session"
  next-device-nonce-key := configuration.optional-string
      config
      "next-device-nonce-key"
      "next-device-nonce"

  state := flash-state.FlashStateStore storage-path
      --initial-device-nonce=initial-device-nonce
      --session-key=session-key
      --next-device-nonce-key=next-device-nonce-key
  credentials := provider.OtaaCredentials
      --application-key=application-key
      --join-eui=join-eui
      --device-eui=device-eui

  opened/hardware.OpenedRadio? := null
  open-end-device := ::
    candidate := hardware.open config
    class-a/device.ClassA? := null
    succeeded := false
    try:
      class-a = device.ClassA
          --radio=candidate
          --region=regional-plan
          --data-rate=data-rate
          --tx-power=tx-power
          --receive-window-ms=receive-window-ms
      opened = candidate
      succeeded = true
    finally:
      if not succeeded: candidate.close
    class-a as device.ClassA
  close-end-device := :: | _/device.ClassA |
    candidate := opened
    opened = null
    if candidate: candidate.close

  provider.install
      --open=open-end-device
      --close=close-end-device
      --state-store=state
      --credentials=credentials

region-from-string_ -> region.Region
    name/string:
  if name == "eu868": return region.Eu868
  if name == "us915": return region.Us915
  throw "LORAWAN_UNKNOWN_REGION"
