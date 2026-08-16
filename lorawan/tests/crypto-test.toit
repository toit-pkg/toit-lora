// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the tests/LICENSE file.

import encoding.hex as hex
import expect show *
import crypto.aes as aes

import lorawan.crypto
import lorawan.frames
import lorawan.region

main:
  cmac-vectors-test
  payload-round-trip-test
  join-request-test
  invalid-device-nonce-test
  join-accept-test
  join-accept-with-channel-list-test
  downlink-round-trip-test
  region-test

cmac-vectors-test:
  key := hex.decode "2b7e151628aed2a6abf7158809cf4f3c"
  expect-equals
      (hex.decode "bb1d6929e95937287fa37d129b756746")
      (crypto.cmac key #[])
  message := hex.decode "6bc1bee22e409f96e93d7e117393172a"
  expect-equals
      (hex.decode "070a16b46b4d4144f79bdd9dd04a287c")
      (crypto.cmac key message)

payload-round-trip-test:
  key := hex.decode "00112233445566778899aabbccddeeff"
  original := "payload longer than one AES block".to-byte-array
  encrypted := crypto.crypt-payload key original
      --direction=crypto.UPLINK
      --device-address=0x2601_1bda
      --frame-counter=0x12345
  expect-not-equals original encrypted
  decrypted := crypto.crypt-payload key encrypted
      --direction=crypto.UPLINK
      --device-address=0x2601_1bda
      --frame-counter=0x12345
  expect-equals original decrypted

join-request-test:
  key := hex.decode "00112233445566778899aabbccddeeff"
  join-eui := hex.decode "0102030405060708"
  device-eui := hex.decode "1122334455667788"
  request := frames.build-join-request key join-eui device-eui 0x1234
  expect-equals 23 request.size
  expect-equals (hex.decode "0807060504030201") request[1..9]
  expect-equals (hex.decode "8877665544332211") request[9..17]
  expect-equals (crypto.join-mic key request[0..19]) request[19..]

invalid-device-nonce-test:
  key := hex.decode "00112233445566778899aabbccddeeff"
  join-eui := hex.decode "0102030405060708"
  device-eui := hex.decode "1122334455667788"
  expect-throw "LORAWAN_INVALID_DEVICE_NONCE":
    frames.build-join-request key join-eui device-eui -1
  expect-throw "LORAWAN_INVALID_DEVICE_NONCE":
    frames.build-join-request key join-eui device-eui 0x1_0000

join-accept-test:
  key := hex.decode "00112233445566778899aabbccddeeff"
  authenticated := hex.decode "20010203040506da1b01260001"
  mic := crypto.join-mic key authenticated
  plaintext := ByteArray 16
  plaintext.replace 0 authenticated 1 authenticated.size
  plaintext.replace 12 mic
  cipher := aes.AesEcb.decryptor key
  encrypted := cipher.decrypt plaintext
  cipher.close
  frame := ByteArray 17
  frame[0] = 0x20
  frame.replace 1 encrypted
  accepted := frames.parse-join-accept key frame 0x1234
  expect-equals 0x2601_1bda accepted.device-address
  expect-equals 1 accepted.receive-delay-seconds
  expect-equals 16 accepted.network-session-key.size
  expect-equals 16 accepted.application-session-key.size

join-accept-with-channel-list-test:
  key := hex.decode "00112233445566778899aabbccddeeff"
  plaintext := hex.decode
      "010203040506da1b01260001184f84e85684b85e84886684586e840000000000"
  authenticated := ByteArray 29
  authenticated[0] = 0x20
  authenticated.replace 1 plaintext 0 28
  plaintext.replace 28 (crypto.join-mic key authenticated)
  encrypted := ByteArray 32
  cipher := aes.AesEcb.decryptor key
  try:
    2.repeat: |index|
      offset := index * 16
      encrypted.replace offset (cipher.decrypt plaintext[offset..offset + 16])
  finally:
    cipher.close
  frame := ByteArray 33
  frame[0] = 0x20
  frame.replace 1 encrypted
  accepted := frames.parse-join-accept key frame 0x1234
  expect-equals 0x2601_1bda accepted.device-address
  expect-equals plaintext[12..28] accepted.channel-frequency-list

downlink-round-trip-test:
  network-key := hex.decode "00112233445566778899aabbccddeeff"
  application-key := hex.decode "ffeeddccbbaa99887766554433221100"
  address := 0x2601_1bda
  counter := 7
  plaintext := "downlink".to-byte-array
  encrypted := crypto.crypt-payload application-key plaintext
      --direction=crypto.DOWNLINK
      --device-address=address
      --frame-counter=counter
  message := ByteArray (9 + encrypted.size)
  message[0] = frames.UNCONFIRMED-DOWN
  4.repeat: |index| message[1 + index] = (address >> (index * 8)) & 0xff
  message[5] = 0x20
  message[6] = counter & 0xff
  message[7] = (counter >> 8) & 0xff
  message[8] = 1
  message.replace 9 encrypted
  mic := crypto.data-mic network-key message
      --direction=crypto.DOWNLINK
      --device-address=address
      --frame-counter=counter
  frame := ByteArray (message.size + 4)
  frame.replace 0 message
  frame.replace message.size mic
  decoded := frames.parse-downlink network-key application-key frame
      --device-address=address
      --frame-counter=counter
  expect-equals plaintext decoded.payload
  expect-equals 1 decoded.port
  expect decoded.acknowledgement

region-test:
  eu := region.Eu868
  eu-uplink := eu.uplink 1 5
  expect-equals 868_300_000 eu-uplink.frequency
  expect-equals 7 eu-uplink.spreading-factor
  expect-equals 9 (eu.rx2 --data-rate=3).spreading-factor
  us := region.Us915
  us-uplink := us.uplink 3 3
  expect-equals 902_900_000 us-uplink.frequency
  expect-equals 242 us-uplink.max-payload-size
  us-downlink := us.rx1 us-uplink.channel 3 0
  expect-equals 7 us-downlink.spreading-factor
  expect-equals 500_000 us-downlink.bandwidth
  expect-equals 925_100_000 us-downlink.frequency
