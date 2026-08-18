// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import io

import .crypto_ as crypto

/** Unconfirmed data-up message type. */
UNCONFIRMED-UP ::= 0x40

/** Confirmed data-up message type. */
CONFIRMED-UP ::= 0x80

/** Unconfirmed data-down message type. */
UNCONFIRMED-DOWN ::= 0x60

/** Confirmed data-down message type. */
CONFIRMED-DOWN ::= 0xa0

/**
Decoded LoRaWAN downlink frame.
*/
class Downlink:
  confirmed/bool
  adr/bool
  acknowledgement/bool
  frame-pending/bool
  frame-counter/int
  options/ByteArray
  port/int?
  payload/ByteArray

  constructor
      --.confirmed/bool
      --.adr/bool
      --.acknowledgement/bool
      --.frame-pending/bool
      --.frame-counter/int
      --.options/ByteArray
      --.port/int?
      --.payload/ByteArray:

/** Decoded and authenticated LoRaWAN 1.0.x join-accept. */
class JoinAccept:
  application-nonce/ByteArray
  network-id/ByteArray
  device-address/int
  network-session-key/ByteArray
  application-session-key/ByteArray
  rx1-offset/int
  rx2-data-rate/int
  receive-delay-seconds/int
  channel-frequency-list/ByteArray

  constructor
      --.application-nonce/ByteArray
      --.network-id/ByteArray
      --.device-address/int
      --.network-session-key/ByteArray
      --.application-session-key/ByteArray
      --.rx1-offset/int
      --.rx2-data-rate/int
      --.receive-delay-seconds/int
      --.channel-frequency-list/ByteArray:

/**
Builds a LoRaWAN 1.0.x join-request PHYPayload.

The EUI arrays use their conventional display order and are reversed for the
  least-significant-byte-first wire representation.
*/
build-join-request -> ByteArray
    --application-key/ByteArray
    --join-eui/ByteArray
    --device-eui/ByteArray
    --device-nonce/int:
  if join-eui.size != 8 or device-eui.size != 8:
    throw "LORAWAN_INVALID_EUI"
  if not 0 <= device-nonce <= 0xffff:
    throw "LORAWAN_INVALID_DEVICE_NONCE"
  message := ByteArray 19
  message[0] = 0x00
  reverse-copy_ message 1 join-eui
  reverse-copy_ message 9 device-eui
  message[17] = device-nonce & 0xff
  message[18] = (device-nonce >> 8) & 0xff
  mic := crypto.join-mic application-key message
  return append_ message mic

/** Decrypts, authenticates, and decodes a LoRaWAN 1.0.x join-accept. */
parse-join-accept -> JoinAccept
    frame/ByteArray
    --application-key/ByteArray
    --device-nonce/int:
  if frame.size != 17 and frame.size != 33:
    throw "LORAWAN_INVALID_JOIN_ACCEPT_LENGTH"
  if (frame[0] & 0xe0) != 0x20: throw "LORAWAN_NOT_A_JOIN_ACCEPT"
  decrypted := crypto.decrypt-join-accept application-key frame[1..]
  received-mic := decrypted[decrypted.size - 4..]
  authenticated := ByteArray (1 + decrypted.size - 4)
  authenticated[0] = frame[0]
  authenticated.replace 1 decrypted 0 (decrypted.size - 4)
  expected-mic := crypto.join-mic application-key authenticated
  if received-mic != expected-mic:
    throw "LORAWAN_MIC_MISMATCH"
  application-nonce := decrypted[0..3]
  network-id := decrypted[3..6]
  address := io.LITTLE-ENDIAN.uint32 decrypted 6
  settings := decrypted[10]
  delay := decrypted[11]
  if delay == 0: delay = 1
  channel-list := decrypted.size == 32 ? decrypted[12..28] : #[]
  network-key := crypto.derive-network-session-key
      application-key
      application-nonce
      network-id
      device-nonce
  application-session-key := crypto.derive-application-session-key
      application-key
      application-nonce
      network-id
      device-nonce
  return JoinAccept
      --application-nonce=application-nonce
      --network-id=network-id
      --device-address=address
      --network-session-key=network-key
      --application-session-key=application-session-key
      --rx1-offset=(settings >> 4) & 0x07
      --rx2-data-rate=settings & 0x0f
      --receive-delay-seconds=delay
      --channel-frequency-list=channel-list

/** Builds an encrypted and authenticated LoRaWAN 1.0.x uplink. */
build-uplink -> ByteArray
    payload/ByteArray
    --network-session-key/ByteArray
    --application-session-key/ByteArray
    --device-address/int
    --frame-counter/int
    --port/int=1
    --confirmed/bool=false
    --adr/bool=false
    --acknowledgement/bool=false
    --options/ByteArray=#[]:
  if options.size > 15: throw "LORAWAN_OPTIONS_TOO_LONG"
  if not 0 <= port <= 255: throw "LORAWAN_INVALID_PORT"
  header-size := 8 + options.size
  message := ByteArray (header-size + 1 + payload.size)
  message[0] = confirmed ? CONFIRMED-UP : UNCONFIRMED-UP
  io.LITTLE-ENDIAN.put-uint32 message 1 device-address
  control := options.size
  if adr: control |= 0x80
  if acknowledgement: control |= 0x20
  message[5] = control
  message[6] = frame-counter & 0xff
  message[7] = (frame-counter >> 8) & 0xff
  message.replace 8 options
  message[header-size] = port
  key := port == 0 ? network-session-key : application-session-key
  encrypted := crypto.crypt-payload key payload
      --direction=crypto.UPLINK
      --device-address=device-address
      --frame-counter=frame-counter
  message.replace (header-size + 1) encrypted
  mic := crypto.data-mic network-session-key message
      --direction=crypto.UPLINK
      --device-address=device-address
      --frame-counter=frame-counter
  return append_ message mic

/**
Verifies and decodes a LoRaWAN 1.0.x downlink.

The caller supplies the reconstructed 32-bit $frame-counter.
*/
parse-downlink -> Downlink
    frame/ByteArray
    --network-session-key/ByteArray
    --application-session-key/ByteArray
    --device-address/int
    --frame-counter/int:
  if frame.size < 12: throw "LORAWAN_DOWNLINK_TOO_SHORT"
  message := frame[0..frame.size - 4]
  received-mic := frame[frame.size - 4..]
  expected-mic := crypto.data-mic network-session-key message
      --direction=crypto.DOWNLINK
      --device-address=device-address
      --frame-counter=frame-counter
  if received-mic != expected-mic: throw "LORAWAN_MIC_MISMATCH"
  message-type := message[0] & 0xe0
  if message-type != UNCONFIRMED-DOWN and message-type != CONFIRMED-DOWN:
    throw "LORAWAN_NOT_A_DOWNLINK"
  received-address := io.LITTLE-ENDIAN.uint32 message 1
  if received-address != device-address: throw "LORAWAN_DEVICE_ADDRESS_MISMATCH"
  control := message[5]
  options-size := control & 0x0f
  payload-offset := 8 + options-size
  if payload-offset > message.size: throw "LORAWAN_INVALID_OPTIONS_LENGTH"
  options := message[8..payload-offset]
  port/int? := null
  payload := ByteArray 0
  if payload-offset < message.size:
    port = message[payload-offset]
    encrypted := message[payload-offset + 1..]
    key := port == 0 ? network-session-key : application-session-key
    payload = crypto.crypt-payload key encrypted
        --direction=crypto.DOWNLINK
        --device-address=device-address
        --frame-counter=frame-counter
  return Downlink
      --confirmed=message-type == CONFIRMED-DOWN
      --adr=(control & 0x80) != 0
      --acknowledgement=(control & 0x20) != 0
      --frame-pending=(control & 0x10) != 0
      --frame-counter=frame-counter
      --options=options
      --port=port
      --payload=payload

append_ -> ByteArray
    first/ByteArray
    second/ByteArray:
  result := ByteArray (first.size + second.size)
  result.replace 0 first
  result.replace first.size second
  return result

reverse-copy_ -> none
    destination/ByteArray
    offset/int
    source/ByteArray:
  size := source.size
  size.repeat: |index|
    destination[offset + index] = source[size - 1 - index]
