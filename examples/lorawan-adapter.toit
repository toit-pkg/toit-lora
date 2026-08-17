// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the examples/LICENSE file.

import lora
import lora.lorawan.device as lorawan
import lora.lorawan.region

/** Adapts a `lora.Radio` to the standalone LoRaWAN radio boundary. */
class RadioAdapter implements lorawan.Radio:
  radio_/lora.Radio

  constructor .radio_:

  /** See $lorawan.Radio.configure. */
  configure
      parameters/region.RadioParameters
      --tx-power/int
      --receive/bool=false
      -> none:
    configuration := lora.Configuration
        --frequency=parameters.frequency
        --bandwidth=parameters.bandwidth
        --spreading-factor=parameters.spreading-factor
        --coding-rate=5
        --preamble-length=8
        --crc=not receive
        --invert-iq=receive
        --sync-word=lora.PUBLIC-SYNC-WORD
        --tx-power=tx-power
    radio_.configure configuration

  /** See $lorawan.Radio.transmit. */
  transmit payload/ByteArray -> none:
    radio_.transmit payload

  /** See $lorawan.Radio.receive. */
  receive --timeout-ms/int -> ByteArray?:
    packet/lora.Packet? := null
    timed-out := catch --unwind=(: it != DEADLINE-EXCEEDED-ERROR):
      with-timeout --ms=timeout-ms: packet = radio_.receive
    return timed-out ? null : packet.payload
