// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the examples/LICENSE file.

import lora
import lorawan.device as lorawan
import lorawan.region

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
    radio_.configure (lora.Configuration
        --frequency=parameters.frequency
        --bandwidth=parameters.bandwidth
        --spreading-factor=parameters.spreading-factor
        --coding-rate=5
        --preamble-length=8
        --crc=not receive
        --invert-iq=receive
        --sync-word=lora.PUBLIC-SYNC-WORD
        --tx-power=tx-power)

  /** See $lorawan.Radio.transmit. */
  transmit payload/ByteArray -> none:
    radio_.transmit payload

  /** See $lorawan.Radio.receive. */
  receive --timeout-ms/int -> ByteArray?:
    packet := radio_.receive --timeout-ms=timeout-ms
    return packet ? packet.payload : null
