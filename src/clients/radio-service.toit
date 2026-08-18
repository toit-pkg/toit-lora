// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import io
import system.services

import ..apis.radio-service as api
import ..radio as lora
import ..radio-service as service

class RadioService-v1 extends services.ServiceClient
    implements service.RadioService-v1:
  static SELECTOR ::= api.SELECTOR-v1

  constructor selector/services.ServiceSelector=SELECTOR:
    assert: selector.matches SELECTOR
    super selector

  transmit payload/io.Data -> none:
    invoke_ api.TRANSMIT-INDEX-v1 (as-byte-array_ payload)

  receive --timeout-ms/int?=null -> lora.Packet?:
    encoded := invoke_ api.RECEIVE-INDEX-v1 timeout-ms
    if not encoded: return null
    return lora.Packet encoded[0] encoded[1] encoded[2]

  standby -> none:
    invoke_ api.STANDBY-INDEX-v1 null

  sleep -> none:
    invoke_ api.SLEEP-INDEX-v1 null

as-byte-array_ data/io.Data -> ByteArray:
  if data is ByteArray: return data as ByteArray
  result := ByteArray data.byte-size
  data.write-to-byte-array result --at=0 0 data.byte-size
  return result
