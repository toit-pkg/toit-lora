// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import .clients.radio-service as clients
import .radio

/**
Opens an exclusive client for the LoRa packet-radio service.

The first connected client that performs an operation owns the radio until it
  closes. A competing client receives `LORA_RADIO_BUSY`.
*/
v1 -> RadioService-v1: return (clients.RadioService-v1).open as any

/** Version 1 of the blocking LoRa packet-radio service. */
interface RadioService-v1:
  /** Applies $configuration to the remote modem. */
  configure configuration/Configuration -> none

  /** Transmits one LoRa $payload. */
  transmit payload/ByteArray -> none

  /**
  Receives one packet, or returns null when $timeout-ms expires.

  A negative timeout waits indefinitely.
  */
  receive --timeout-ms/int=-1 -> Packet?

  /** Puts the remote radio into standby mode. */
  standby -> none

  /** Puts the remote radio into its lowest-power sleep mode. */
  sleep-radio -> none

  /** Releases the service client and its exclusive radio ownership. */
  close -> none
