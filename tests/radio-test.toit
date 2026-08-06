// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the tests/LICENSE file.

import expect show *
import lora

main:
  configuration-test
  packet-test

configuration-test:
  configuration := lora.Configuration
      --frequency=915_000_000
      --bandwidth=250_000
      --spreading-factor=9
      --coding-rate=6
      --preamble-length=12
      --no-crc
      --invert-iq
      --sync-word=lora.PUBLIC-SYNC-WORD
      --tx-power=20
  expect-equals 915_000_000 configuration.frequency
  expect-equals 250_000 configuration.bandwidth
  expect-equals 9 configuration.spreading-factor
  expect-equals 6 configuration.coding-rate
  expect-equals 12 configuration.preamble-length
  expect-not configuration.crc
  expect configuration.invert-iq
  expect-equals lora.PUBLIC-SYNC-WORD configuration.sync-word
  expect-equals 20 configuration.tx-power

packet-test:
  packet := lora.Packet #[1, 2, 3] -73.5 8.25
  expect-equals #[1, 2, 3] packet.payload
  expect-equals -73.5 packet.rssi
  expect-equals 8.25 packet.snr
