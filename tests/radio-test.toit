// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the tests/LICENSE file.

import expect show *
import lora
import lora.providers.radio-service as provider
import lora.radio-service as service

main:
  configuration-test
  packet-test
  service-test

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

service-test:
  radio := FakeRadio
  installed := provider.install radio
  first := service.v1
  second := service.v1
  try:
    configuration := lora.Configuration --frequency=868_300_000
    first.configure configuration
    first.transmit #[1, 2, 3]
    packet := first.receive --timeout-ms=17
    expect-equals #[4, 5, 6] packet.payload
    expect-equals -91.0 packet.rssi
    expect-equals 7.5 packet.snr
    expect-equals 868_300_000 radio.configuration.frequency
    expect-equals #[1, 2, 3] radio.transmitted
    expect-equals 17 radio.timeout-ms
    expect-throw "LORA_RADIO_BUSY":
      second.standby
    first.close
    second.standby
    expect-equals 2 radio.standby-count
  finally:
    first.close
    second.close
    installed.uninstall

class FakeRadio implements lora.Radio:
  configuration/lora.Configuration? := null
  transmitted/ByteArray? := null
  timeout-ms/int? := null
  standby-count/int := 0

  configure configuration/lora.Configuration -> none:
    this.configuration = configuration

  transmit payload/ByteArray -> none:
    transmitted = payload

  receive --timeout-ms/int=-1 -> lora.Packet?:
    this.timeout-ms = timeout-ms
    return lora.Packet #[4, 5, 6] -91.0 7.5

  standby -> none:
    standby-count++

  sleep-radio -> none:

  close -> none:
