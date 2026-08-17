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
  session-key_/string
  next-device-nonce-key_/string

  constructor
      path/string
      --initial-device-nonce/int=0
      --session-key/string=SESSION-KEY_
      --next-device-nonce-key/string=NEXT-DEVICE-NONCE-KEY_:
    if not 0 <= initial-device-nonce <= 0xffff:
      throw "LORAWAN_INVALID_DEVICE_NONCE"
    initial-device-nonce_ = initial-device-nonce
    session-key_ = session-key
    next-device-nonce-key_ = next-device-nonce-key
    bucket_ = storage.Bucket.open --flash path

  /** See $provider.StateStore.load-session. */
  load-session -> device.Session?:
    encoded := bucket_.get session-key_
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
        --device-address=encoded[0]
        --network-session-key=encoded[1]
        --application-session-key=encoded[2]
        --uplink-counter=encoded[3]
        --downlink-counter=encoded[4]

  /** See $provider.StateStore.reserve-device-nonce. */
  reserve-device-nonce -> int:
    reserved := 0
    critical-do --no-respect-deadline:
      next := bucket_.get next-device-nonce-key_
          --if-absent=: initial-device-nonce_
      if next is not int: throw "LORAWAN_CORRUPT_PERSISTENT_STATE"
      if not 0 <= next <= 0xffff: throw "LORAWAN_DEVICE_NONCE_EXHAUSTED"
      bucket_[next-device-nonce-key_] = next + 1
      reserved = next
    return reserved

  /** See $provider.StateStore.save-session. */
  save-session -> none
      session/device.Session:
    critical-do --no-respect-deadline:
      bucket_[session-key_] = [
        session.device-address,
        session.network-session-key,
        session.application-session-key,
        session.uplink-counter,
        session.downlink-counter,
      ]

  /** Closes the backing storage bucket. */
  close -> none:
    bucket_.close
