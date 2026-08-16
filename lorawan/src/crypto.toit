// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import crypto.aes as aes

/** LoRaWAN uplink direction value. */
UPLINK ::= 0

/** LoRaWAN downlink direction value. */
DOWNLINK ::= 1

/**
Computes AES-CMAC as defined by RFC 4493.
*/
cmac key/ByteArray message/ByteArray -> ByteArray:
  validate-key_ key
  zero := ByteArray 16
  l := aes-block_ key zero
  k1 := subkey_ l
  k2 := subkey_ k1
  complete := message.size > 0 and (message.size % 16) == 0
  block-count := max 1 ((message.size + 15) / 16)
  last := ByteArray 16
  if complete:
    last.replace 0 message (message.size - 16) message.size
    xor-in-place_ last k1
  else:
    remainder := message.size % 16
    if remainder > 0:
      last.replace 0 message (message.size - remainder) message.size
    last[remainder] = 0x80
    xor-in-place_ last k2
  state := ByteArray 16
  (block-count - 1).repeat: |index|
    block := message[index * 16..index * 16 + 16]
    xor-in-place_ block state
    state = aes-block_ key block
  xor-in-place_ last state
  return aes-block_ key last

/**
Computes a four-byte LoRaWAN data-frame MIC.
*/
data-mic
    network-session-key/ByteArray
    message/ByteArray
    --direction/int
    --device-address/int
    --frame-counter/int
    -> ByteArray:
  b0 := ByteArray 16
  b0[0] = 0x49
  b0[5] = direction
  put-uint32-le_ b0 6 device-address
  put-uint32-le_ b0 10 frame-counter
  b0[15] = message.size
  input := concatenate_ b0 message
  return (cmac network-session-key input)[0..4]

/**
Encrypts or decrypts a LoRaWAN FRMPayload.

LoRaWAN payload encryption is symmetric, so applying this function twice with
  the same parameters returns the original payload.
*/
crypt-payload
    session-key/ByteArray
    payload/ByteArray
    --direction/int
    --device-address/int
    --frame-counter/int
    -> ByteArray:
  validate-key_ session-key
  result := payload.copy
  blocks := (payload.size + 15) / 16
  blocks.repeat: |index|
    a := ByteArray 16
    a[0] = 0x01
    a[5] = direction
    put-uint32-le_ a 6 device-address
    put-uint32-le_ a 10 frame-counter
    a[15] = index + 1
    stream := aes-block_ session-key a
    from := index * 16
    to := min payload.size (from + 16)
    (to - from).repeat: |offset|
      result[from + offset] ^= stream[offset]
  return result

/** Computes the MIC used by join-request and join-accept messages. */
join-mic application-key/ByteArray message/ByteArray -> ByteArray:
  return (cmac application-key message)[0..4]

/**
Decrypts the encrypted portion of a LoRaWAN 1.0.x join-accept.

The network uses the AES decrypt operation when constructing a join-accept, so
  an end device intentionally uses AES encryption here.
*/
decrypt-join-accept application-key/ByteArray encrypted/ByteArray -> ByteArray:
  if encrypted.size == 0 or (encrypted.size % 16) != 0:
    throw "LORAWAN_INVALID_JOIN_ACCEPT_LENGTH"
  return aes-crypt-blocks_ application-key encrypted --encrypt

/** Derives the LoRaWAN 1.0.x network session key. */
derive-network-session-key
    application-key/ByteArray
    application-nonce/ByteArray
    network-id/ByteArray
    device-nonce/int
    -> ByteArray:
  return derive-session-key_
      application-key
      application-nonce
      network-id
      device-nonce
      0x01

/** Derives the LoRaWAN 1.0.x application session key. */
derive-application-session-key
    application-key/ByteArray
    application-nonce/ByteArray
    network-id/ByteArray
    device-nonce/int
    -> ByteArray:
  return derive-session-key_
      application-key
      application-nonce
      network-id
      device-nonce
      0x02

derive-session-key_
    key/ByteArray
    application-nonce/ByteArray
    network-id/ByteArray
    device-nonce/int
    kind/int
    -> ByteArray:
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

aes-block_ key/ByteArray block/ByteArray -> ByteArray:
  cipher := aes.AesEcb.encryptor key
  try:
    return cipher.encrypt block
  finally:
    cipher.close

aes-crypt-blocks_ key/ByteArray input/ByteArray --encrypt/bool -> ByteArray:
  cipher := encrypt
      ? aes.AesEcb.encryptor key
      : aes.AesEcb.decryptor key
  try:
    result := ByteArray input.size
    (input.size / 16).repeat: |index|
      offset := index * 16
      block := input[offset..offset + 16]
      transformed := encrypt ? cipher.encrypt block : cipher.decrypt block
      result.replace offset transformed
    return result
  finally:
    cipher.close

subkey_ input/ByteArray -> ByteArray:
  output := ByteArray 16
  carry := 0
  16.repeat: |offset|
    index := 15 - offset
    value := input[index]
    output[index] = ((value << 1) & 0xff) | carry
    carry = (value >> 7) & 1
  if (input[0] & 0x80) != 0: output[15] ^= 0x87
  return output

xor-in-place_ target/ByteArray other/ByteArray -> none:
  target.size.repeat: |index| target[index] ^= other[index]

validate-key_ key/ByteArray -> none:
  if key.size != 16: throw "LORAWAN_INVALID_AES_KEY"

concatenate_ first/ByteArray second/ByteArray -> ByteArray:
  result := ByteArray (first.size + second.size)
  result.replace 0 first
  result.replace first.size second
  return result

put-uint32-le_ bytes/ByteArray offset/int value/int -> none:
  4.repeat: |index| bytes[offset + index] = (value >> (index * 8)) & 0xff
