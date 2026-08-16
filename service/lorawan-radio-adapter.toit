// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the LICENSE file.

import lora
import lorawan.device
import lorawan.region

/** Adapts a plain LoRa radio to the LoRaWAN provider boundary. */
class LorawanRadioAdapter implements device.Radio:
  radio_/lora.Radio

  constructor .radio_:

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

  transmit payload/ByteArray -> none:
    radio_.transmit payload

  receive --timeout-ms/int -> ByteArray?:
    packet := radio_.receive --timeout-ms=timeout-ms
    return packet ? packet.payload : null
