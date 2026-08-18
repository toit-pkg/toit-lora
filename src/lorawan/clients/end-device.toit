// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import system.services
import io

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

  send -> frames.Downlink?
      payload/io.Data
      --port/int=1
      --confirmed/bool=false
      --adr/bool=false:
    encoded := invoke_ api.SEND-INDEX-v1 [payload, port, confirmed, adr]
    if not encoded: return null
    return frames.Downlink
        --confirmed=encoded[0]
        --adr=encoded[1]
        --acknowledgement=encoded[2]
        --frame-pending=encoded[3]
        --frame-counter=encoded[4]
        --options=encoded[5]
        --port=encoded[6]
        --payload=encoded[7]
