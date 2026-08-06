// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the examples/LICENSE file.

import lorawan.end-device

main:
  device := end-device.v1
  try:
    if not device.activated and not device.join:
      print "OTAA_JOIN_TIMEOUT"
      return
    downlink := device.send "hello-from-service-client".to-byte-array
    print "LORAWAN_UPLINK_SENT"
    if downlink:
      print "LORAWAN_DOWNLINK port=$(downlink.port) bytes=$(downlink.payload.size)"
  finally:
    device.close
