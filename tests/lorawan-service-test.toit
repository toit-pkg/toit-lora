// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the tests/LICENSE file.

import expect show *
import io
import monitor

import lora
import lora.lorawan.device
import lora.lorawan.end-device as end-device-service
import lora.lorawan.providers.end-device as provider
import lora.lorawan.region

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
  session := device.Session
      --device-address=0x2601_1bda
      --network-session-key=key
      --application-session-key=key
  state := provider.MemoryStateStore --session=session
  radios/List := []
  installed := provider.install
      --open=::
        radio := FakeRadio state
        radios.add radio
        device.ClassA
            --radio=radio
            --region=region.Eu868
            --receive-delay-ms=1
            --receive-window-ms=1
      --close=:: |end-device/device.ClassA|
        (radios[radios.size - 1] as FakeRadio).close
      --state-store=state
  client := end-device-service.v1
  peer := end-device-service.v1
  try:
    expect radios.is-empty
    expect client.activated
    expect-equals 1 radios.size
    radio/FakeRadio := radios[0]
    expect client.join
    expect (client.send #[1, 2, 3] --port=7) == null
    expect-equals 1 state.load-session.uplink-counter
    expect-equals 1 radio.persisted-counter-at-transmit
    expect-equals 1 radio.transmitted.size
    client.close
    expect-equals 0 radio.close-count
    expect peer.activated
  finally:
    client.close
    peer.close
  expect-equals 1 (radios[0] as FakeRadio).close-count
  second := end-device-service.v1
  try:
    expect second.activated
    expect-equals 2 radios.size
  finally:
    second.close
    installed.uninstall
  expect-equals 1 (radios[1] as FakeRadio).close-count

class FakeRadio implements lora.Radio:
  state_/provider.StateStore
  transmitted/List := []
  persisted-counter-at-transmit/int? := null
  close-count/int := 0
  receive-signal_/monitor.Signal ::= monitor.Signal

  constructor .state_:

  configure -> none
      configuration/lora.Configuration:

  transmit -> none
      payload/io.Data:
    persisted-counter-at-transmit = state_.load-session.uplink-counter
    transmitted.add payload

  receive --header-timeout-ms/int?=null -> lora.Packet?:
    if header-timeout-ms: return null
    receive-signal_.wait
    unreachable

  standby -> none:

  sleep -> none:

  close -> none:
    close-count++
