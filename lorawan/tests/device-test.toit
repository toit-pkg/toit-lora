// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the tests/LICENSE file.

import expect show *

import lorawan.device
import lorawan.region

class RecordingRadio implements device.Radio:
  configuration-times/List := []
  receive-times/List := []
  receive-timeouts/List := []

  configure
      parameters/region.RadioParameters
      --tx-power/int
      --receive/bool=false
      -> none:
    configuration-times.add Time.monotonic-us

  transmit payload/ByteArray -> none:

  receive --timeout-ms/int -> ByteArray?:
    receive-times.add Time.monotonic-us
    receive-timeouts.add timeout-ms
    return null

main:
  receive-windows-are-configured-ahead-of-time-test

receive-windows-are-configured-ahead-of-time-test:
  radio := RecordingRadio
  key := ByteArray 16
  session := device.Session 0x2601_1bda key key
  endpoint := device.ClassA radio region.Eu868
      --session=session
      --receive-delay-ms=250
      --receive-window-ms=1

  expect (endpoint.send #[1]) == null
  expect-equals 3 radio.configuration-times.size
  expect-equals 2 radio.receive-times.size
  expect-equals 1 radio.receive-timeouts[0]
  expect-equals 1 radio.receive-timeouts[1]

  // The radio must be configured before each receive deadline, not after it.
  expect radio.receive-times[0] - radio.configuration-times[1] > 100_000
  expect radio.receive-times[1] - radio.configuration-times[2] > 700_000
