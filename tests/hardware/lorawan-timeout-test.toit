// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the tests/LICENSE file.

import lora.lorawan.end-device

main:
  first := end-device.v1
  try:
    timed-out := catch --unwind=(: it != DEADLINE-EXCEEDED-ERROR):
      with-timeout --ms=100:
        first.send "deadline-test" --port=2
    if not timed-out: throw "EXPECTED_LORAWAN_DEADLINE"
    print "LORAWAN_EXPECTED_TIMEOUT"
  finally:
    first.close

  second := end-device.v1
  try:
    if not second.activated: throw "LORAWAN_SESSION_LOST_AFTER_TIMEOUT"
    second.send "after-timeout" --port=2
    print "LORAWAN_RECOVERED_AFTER_TIMEOUT"
  finally:
    second.close
