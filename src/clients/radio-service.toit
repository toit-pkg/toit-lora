// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import system.services

import ..apis.radio-service as api
import ..radio as lora
import ..radio-service as service

class RadioService-v1 extends services.ServiceClient
    implements
      service.RadioService-v1
      lora.Radio:
  static SELECTOR ::= api.SELECTOR-v1

  constructor selector/services.ServiceSelector=SELECTOR:
    assert: selector.matches SELECTOR
    super selector

  configure configuration/lora.Configuration -> none:
    invoke_ api.CONFIGURE-INDEX-v1 [
      configuration.frequency,
      configuration.bandwidth,
      configuration.spreading-factor,
      configuration.coding-rate,
      configuration.preamble-length,
      configuration.crc,
      configuration.invert-iq,
      configuration.sync-word,
      configuration.tx-power,
    ]

  transmit payload/ByteArray -> none:
    invoke_ api.TRANSMIT-INDEX-v1 payload

  receive --timeout-ms/int?=null -> lora.Packet?:
    encoded := invoke_ api.RECEIVE-INDEX-v1 timeout-ms
    if not encoded: return null
    return lora.Packet encoded[0] encoded[1] encoded[2]

  standby -> none:
    invoke_ api.STANDBY-INDEX-v1 null

  sleep -> none:
    invoke_ api.SLEEP-INDEX-v1 null
