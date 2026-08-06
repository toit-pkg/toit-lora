// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import .clients.end-device as clients
import .frames

/**
Opens a client for the LoRaWAN end-device service.

The provider owns activation credentials, persistent protocol state, and the
  physical radio. Calls from multiple clients are serialized by the provider.
*/
v1 -> EndDeviceService-v1: return (clients.EndDeviceService-v1).open as any

/** Version 1 of the LoRaWAN Class A end-device service. */
interface EndDeviceService-v1:
  /** Reports whether the provider has an active session. */
  activated -> bool

  /** Joins the configured network and reports whether activation succeeded. */
  join -> bool

  /**
  Sends an application $payload and returns a downlink received in RX1 or RX2.

  The $port must be an application port supported by the protocol layer.
  */
  send
      payload/ByteArray
      --port/int=1
      --confirmed/bool=false
      --adr/bool=false
      -> Downlink?

  /** Releases the service client. */
  close -> none
