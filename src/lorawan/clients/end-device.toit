// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import system.services

import ..apis.end-device as api
import ..end-device as service
import ..frames as frames

class EndDeviceService-v1 extends services.ServiceClient
    implements service.EndDeviceService-v1:
  static SELECTOR ::= api.SELECTOR-v1

  constructor selector/services.ServiceSelector=SELECTOR:
    assert: selector.matches SELECTOR
    super selector

  activated -> bool:
    return invoke_ api.ACTIVATED-INDEX-v1 null

  join -> bool:
    return invoke_ api.JOIN-INDEX-v1 null

  send
      payload/ByteArray
      --port/int=1
      --confirmed/bool=false
      --adr/bool=false
      -> frames.Downlink?:
    encoded := invoke_ api.SEND-INDEX-v1 [payload, port, confirmed, adr]
    if not encoded: return null
    return frames.Downlink
        encoded[0]
        encoded[1]
        encoded[2]
        encoded[3]
        encoded[4]
        encoded[5]
        encoded[6]
        encoded[7]
