// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the LICENSE file.

import lora
import lora.providers.radio-service as provider

import .configuration as configuration
import .hardware as hardware

main args/List:
  if not args.is-empty: throw "Configure the radio using container assets"
  config := configuration.load
  radio-configuration := radio-configuration_ config
  provider.install --open=::
    opened := hardware.open config
    result/lora.Radio? := null
    succeeded := false
    try:
      opened.configure radio-configuration
      result = opened
      succeeded = true
    finally:
      if not succeeded: opened.close
    result as lora.Radio

radio-configuration_ config/Map -> lora.Configuration:
  return lora.Configuration
      --frequency=(configuration.optional-int config "frequency" 868_100_000)
      --bandwidth=(configuration.optional-int config "bandwidth" 125_000)
      --spreading-factor=(configuration.optional-int config "spreading-factor" 7)
      --coding-rate=(configuration.optional-int config "coding-rate" 5)
      --preamble-length=(configuration.optional-int config "preamble-length" 8)
      --crc=(configuration.optional-bool config "crc" true)
      --invert-iq=(configuration.optional-bool config "invert-iq" false)
      --sync-word=(configuration.optional-int config "sync-word" lora.PRIVATE-SYNC-WORD)
      --tx-power=(configuration.optional-int config "tx-power" 14)
