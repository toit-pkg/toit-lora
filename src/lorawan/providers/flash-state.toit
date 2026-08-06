// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import system.storage

import ..device as device
import .end-device as provider

SESSION-KEY_ ::= "session"
NEXT-DEVICE-NONCE-KEY_ ::= "next-device-nonce"

/** Flash-backed LoRaWAN session and DevNonce state. */
class FlashStateStore implements provider.StateStore:
  bucket_/storage.Bucket
  initial-device-nonce_/int

  constructor path/string --initial-device-nonce/int=0:
    if initial-device-nonce < 0 or initial-device-nonce > 0xffff:
      throw "LORAWAN_INVALID_DEVICE_NONCE"
    initial-device-nonce_ = initial-device-nonce
    bucket_ = storage.Bucket.open --flash path

  /** See $provider.StateStore.load-session. */
  load-session -> device.Session?:
    encoded := bucket_.get SESSION-KEY_
    if not encoded: return null
    if encoded is not List or encoded.size != 5:
      throw "LORAWAN_CORRUPT_PERSISTENT_STATE"
    if encoded[0] is not int or
        encoded[1] is not ByteArray or
        encoded[2] is not ByteArray or
        encoded[3] is not int or
        encoded[4] is not int:
      throw "LORAWAN_CORRUPT_PERSISTENT_STATE"
    return device.Session
        encoded[0]
        encoded[1]
        encoded[2]
        --uplink-counter=encoded[3]
        --downlink-counter=encoded[4]

  /** See $provider.StateStore.reserve-device-nonce. */
  reserve-device-nonce -> int:
    next := bucket_.get NEXT-DEVICE-NONCE-KEY_
        --if-absent=: initial-device-nonce_
    if next is not int: throw "LORAWAN_CORRUPT_PERSISTENT_STATE"
    if next < 0 or next > 0xffff: throw "LORAWAN_DEVICE_NONCE_EXHAUSTED"
    bucket_[NEXT-DEVICE-NONCE-KEY_] = next + 1
    return next

  /** See $provider.StateStore.save-session. */
  save-session session/device.Session -> none:
    bucket_[SESSION-KEY_] = [
      session.device-address,
      session.network-session-key,
      session.application-session-key,
      session.uplink-counter,
      session.downlink-counter,
    ]

  /** Closes the backing storage bucket. */
  close -> none:
    bucket_.close
