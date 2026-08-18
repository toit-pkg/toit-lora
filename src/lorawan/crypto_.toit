// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import crypto.aes as aes
import crypto.cmac as sdk-cmac
import io

/** LoRaWAN uplink direction value. */
UPLINK ::= 0

/** LoRaWAN downlink direction value. */
DOWNLINK ::= 1

/**
Computes AES-CMAC as defined by RFC 4493.
*/
cmac -> ByteArray
    key/ByteArray
    message/ByteArray:
  validate-key_ key
  return sdk-cmac.cmac --key=key message

/**
Computes a four-byte LoRaWAN data-frame MIC.
*/
data-mic -> ByteArray
    network-session-key/ByteArray
    message/ByteArray
    --direction/int
    --device-address/int
    --frame-counter/int:
  b0 := ByteArray 16
  b0[0] = 0x49
  b0[5] = direction
  io.LITTLE-ENDIAN.put-uint32 b0 6 device-address
  io.LITTLE-ENDIAN.put-uint32 b0 10 frame-counter
  b0[15] = message.size
  input := concatenate_ b0 message
  return (cmac network-session-key input)[0..4]

/**
Encrypts or decrypts a LoRaWAN FRMPayload.

LoRaWAN payload encryption is symmetric, so applying this function twice with
  the same parameters returns the original payload.
*/
crypt-payload -> ByteArray
    session-key/ByteArray
    payload/ByteArray
    --direction/int
    --device-address/int
    --frame-counter/int:
  validate-key_ session-key
  result := payload.copy
  blocks := (payload.size + 15) / 16
  blocks.repeat: |index|
    a := ByteArray 16
    a[0] = 0x01
    a[5] = direction
    io.LITTLE-ENDIAN.put-uint32 a 6 device-address
    io.LITTLE-ENDIAN.put-uint32 a 10 frame-counter
    a[15] = index + 1
    stream := aes-block_ session-key a
    from := index * 16
    to := min payload.size (from + 16)
    (to - from).repeat: |offset|
      result[from + offset] ^= stream[offset]
  return result

/** Computes the MIC used by join-request and join-accept messages. */
join-mic -> ByteArray
    application-key/ByteArray
    message/ByteArray:
  return (cmac application-key message)[0..4]

/**
Decrypts the encrypted portion of a LoRaWAN 1.0.x join-accept.

The network uses the AES decrypt operation when constructing a join-accept, so
  an end device intentionally uses AES encryption here.
*/
decrypt-join-accept -> ByteArray
    application-key/ByteArray
    encrypted/ByteArray:
  if encrypted.size == 0 or (encrypted.size % 16) != 0:
    throw "LORAWAN_INVALID_JOIN_ACCEPT_LENGTH"
  return aes-crypt-blocks_ application-key encrypted --encrypt

/** Derives the LoRaWAN 1.0.x network session key. */
derive-network-session-key -> ByteArray
    application-key/ByteArray
    application-nonce/ByteArray
    network-id/ByteArray
    device-nonce/int:
  return derive-session-key_
      application-key
      application-nonce
      network-id
      device-nonce
      0x01

/** Derives the LoRaWAN 1.0.x application session key. */
derive-application-session-key -> ByteArray
    application-key/ByteArray
    application-nonce/ByteArray
    network-id/ByteArray
    device-nonce/int:
  return derive-session-key_
      application-key
      application-nonce
      network-id
      device-nonce
      0x02

derive-session-key_ -> ByteArray
    key/ByteArray
    application-nonce/ByteArray
    network-id/ByteArray
    device-nonce/int
    kind/int:
  validate-key_ key
  if application-nonce.size != 3 or network-id.size != 3:
    throw "LORAWAN_INVALID_JOIN_PARAMETER"
  block := ByteArray 16
  block[0] = kind
  block.replace 1 application-nonce
  block.replace 4 network-id
  block[7] = device-nonce & 0xff
  block[8] = (device-nonce >> 8) & 0xff
  return aes-block_ key block

aes-block_ -> ByteArray
    key/ByteArray
    block/ByteArray:
  cipher := aes.AesEcb.encryptor key
  try:
    return cipher.encrypt block
  finally:
    cipher.close

aes-crypt-blocks_ -> ByteArray
    key/ByteArray
    input/ByteArray
    --encrypt/bool:
  cipher := encrypt
      ? aes.AesEcb.encryptor key
      : aes.AesEcb.decryptor key
  try:
    return encrypt ? cipher.encrypt input : cipher.decrypt input
  finally:
    cipher.close

validate-key_ -> none
    key/ByteArray:
  if key.size != 16: throw "LORAWAN_INVALID_AES_KEY"

concatenate_ -> ByteArray
    first/ByteArray
    second/ByteArray:
  result := ByteArray (first.size + second.size)
  result.replace 0 first
  result.replace first.size second
  return result
