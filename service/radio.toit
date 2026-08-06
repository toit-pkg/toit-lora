// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the LICENSE file.

import lora.providers.radio-service as provider

import .configuration as configuration
import .hardware as hardware

main args/List:
  config := args.is-empty
      ? configuration.load
      : configuration-from-args_ args
  opened := hardware.open (configuration.required-string config "board")
  installed := provider.install opened.radio
  try:
    while true: sleep --ms=60_000
  finally:
    installed.uninstall
    opened.close

configuration-from-args_ args/List -> Map:
  if args.size != 1: throw "Usage: radio <heltec|lilygo>"
  return {"board": args[0]}
