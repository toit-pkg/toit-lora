// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the tests/LICENSE file.

import expect show *
import core.timer as timer
import io
import monitor

import lora
import lora.lorawan.device
import lora.lorawan.region

class RecordingRadio implements lora.Radio:
  configuration-times/List := []
  receive-times/List := []
  receive-signal_/monitor.Signal ::= monitor.Signal

  configure configuration/lora.Configuration -> none:
    configuration-times.add Time.monotonic-us

  transmit payload/io.Data -> none:

  receive --header-timeout-ms/int?=null -> lora.Packet?:
    receive-times.add Time.monotonic-us
    if header-timeout-ms:
      timer.sleep --ms=header-timeout-ms
      return null
    receive-signal_.wait
    unreachable

  standby -> none:

  sleep -> none:

  close -> none:

main:
  receive-windows-are-configured-ahead-of-time-test
  caller-deadline-is-not-swallowed-test

receive-windows-are-configured-ahead-of-time-test:
  radio := RecordingRadio
  key := ByteArray 16
  session := device.Session
      --device-address=0x2601_1bda
      --network-session-key=key
      --application-session-key=key
  endpoint := device.ClassA
      --radio=radio
      --region=region.Eu868
      --session=session
      --receive-delay-ms=250
      --receive-window-ms=1

  expect (endpoint.send #[1]) == null
  expect-equals 3 radio.configuration-times.size
  expect-equals 2 radio.receive-times.size

  // The radio must be configured before each receive deadline, not after it.
  expect radio.receive-times[0] - radio.configuration-times[1] > 100_000
  expect radio.receive-times[1] - radio.configuration-times[2] > 700_000

caller-deadline-is-not-swallowed-test:
  radio := RecordingRadio
  key := ByteArray 16
  session := device.Session
      --device-address=0x2601_1bda
      --network-session-key=key
      --application-session-key=key
  endpoint := device.ClassA
      --radio=radio
      --region=region.Eu868
      --session=session
      --receive-delay-ms=0
      --receive-window-ms=1_000

  expect-throw DEADLINE-EXCEEDED-ERROR:
    with-timeout --ms=20: endpoint.send #[1]
