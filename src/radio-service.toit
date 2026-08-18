// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import io

import .clients.radio-service as clients
import .radio show Packet

/**
Opens a client for the LoRa packet-radio service.

The provider owns the modem configuration. Operations from all clients are
  serialized on the shared radio.
*/
v1 -> RadioService-v1: return (clients.RadioService-v1).open as any

/** Version 1 of the blocking LoRa packet-radio service. */
interface RadioService-v1:
  /** Transmits one LoRa $payload. */
  transmit payload/io.Data -> none

  /**
  Receives one packet, or returns null when $timeout-ms expires.

  A null timeout waits indefinitely.
  */
  receive --timeout-ms/int?=null -> Packet?

  /** Puts the remote radio into standby mode. */
  standby -> none

  /** Puts the remote radio into its lowest-power sleep mode. */
  sleep -> none

  /** Releases the service client. */
  close -> none
