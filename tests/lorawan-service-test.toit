// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the tests/LICENSE file.

import expect show *

import lorawan.device
import lorawan.end-device as end-device-service
import lorawan.providers.end-device as provider
import lorawan.region

main:
  memory-state-test
  end-device-service-test

memory-state-test:
  state := provider.MemoryStateStore --next-device-nonce=0xffff
  expect-equals 0xffff state.reserve-device-nonce
  expect-throw "LORAWAN_DEVICE_NONCE_EXHAUSTED":
    state.reserve-device-nonce

end-device-service-test:
  key := ByteArray 16
  session := device.Session 0x2601_1bda key key
  state := provider.MemoryStateStore --session=session
  radio := FakeRadio state
  class-a := device.ClassA
      radio
      region.Eu868
      --receive-delay-ms=1
      --receive-window-ms=1
  installed := provider.install class-a state
  client := end-device-service.v1
  try:
    expect client.activated
    expect client.join
    expect (client.send #[1, 2, 3] --port=7) == null
    expect-equals 1 class-a.session.uplink-counter
    expect-equals 1 state.load-session.uplink-counter
    expect-equals 1 radio.persisted-counter-at-transmit
    expect-equals 1 radio.transmitted.size
  finally:
    client.close
    installed.uninstall

class FakeRadio implements device.Radio:
  state_/provider.StateStore
  transmitted/List := []
  persisted-counter-at-transmit/int? := null

  constructor .state_:

  configure
      parameters/region.RadioParameters
      --tx-power/int
      --receive/bool=false
      -> none:

  transmit payload/ByteArray -> none:
    persisted-counter-at-transmit = state_.load-session.uplink-counter
    transmitted.add payload

  receive --timeout-ms/int -> ByteArray?:
    return null
