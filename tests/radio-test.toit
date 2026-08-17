// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the tests/LICENSE file.

import expect show *
import io
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
  radios/List := []
  installed := provider.install --open=::
    radio := FakeRadio
    radios.add radio
    radio
  first := service.v1
  second := service.v1
  try:
    expect radios.is-empty
    first.transmit "first"
    radio/FakeRadio := radios[0]
    second.transmit #[1, 2, 3]
    packet := first.receive --timeout-ms=17
    expect-equals #[4, 5, 6] packet.payload
    expect-equals -91.0 packet.rssi
    expect-equals 7.5 packet.snr
    expect-equals ["first".to-byte-array, #[1, 2, 3]] radio.transmitted
    first.close
    expect-equals 0 radio.close-count
    second.standby
    expect-equals 1 radio.standby-count
  finally:
    first.close
    second.close
  expect-equals 1 radios.size
  expect-equals 1 (radios[0] as FakeRadio).close-count
  third := service.v1
  try:
    third.transmit "third"
  finally:
    third.close
    installed.uninstall
  expect-equals 2 radios.size
  expect-equals 1 (radios[1] as FakeRadio).close-count

class FakeRadio implements lora.Radio:
  configuration/lora.Configuration? := null
  transmitted/List := []
  standby-count/int := 0
  close-count/int := 0

  configure configuration/lora.Configuration -> none:
    this.configuration = configuration

  transmit payload/io.Data -> none:
    bytes := ByteArray payload.byte-size
    payload.write-to-byte-array bytes --at=0 0 payload.byte-size
    transmitted.add bytes

  receive -> lora.Packet:
    return lora.Packet #[4, 5, 6] -91.0 7.5

  standby -> none:
    standby-count++

  sleep -> none:

  close -> none:
    close-count++
