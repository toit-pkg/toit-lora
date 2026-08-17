// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import io

/** The private-network LoRa sync word. */
PRIVATE-SYNC-WORD ::= 0x12

/** The public-network and LoRaWAN sync word. */
PUBLIC-SYNC-WORD ::= 0x34

/** Maximum LoRa PHY payload size supported by the radios. */
MAX-PAYLOAD-SIZE ::= 255

/**
LoRa modem configuration shared by all supported radio families.
*/
class Configuration:
  /** Carrier frequency in Hz. */
  frequency/int

  /** LoRa signal bandwidth in Hz. */
  bandwidth/int

  /** LoRa spreading factor in the range 7 through 12. */
  spreading-factor/int

  /** Coding-rate denominator for coding rates 4/5 through 4/8. */
  coding-rate/int

  /** Preamble length in symbols. */
  preamble-length/int

  /** Enables the LoRa payload CRC. */
  crc/bool

  /** Enables inverted LoRa in-phase/quadrature polarity. */
  invert-iq/bool

  /** Eight-bit LoRa sync word. */
  sync-word/int

  /** Transmit power in dBm. */
  tx-power/int

  constructor
      --.frequency/int=868_100_000
      --.bandwidth/int=125_000
      --.spreading-factor/int=7
      --.coding-rate/int=5
      --.preamble-length/int=8
      --.crc/bool=true
      --.invert-iq/bool=false
      --.sync-word/int=PRIVATE-SYNC-WORD
      --.tx-power/int=14:
    validate

  /** Validates this configuration. */
  validate -> none:
    if not 137_000_000 <= frequency <= 1_020_000_000:
      throw "LORA_INVALID_FREQUENCY"
    if not 7 <= spreading-factor <= 12:
      throw "LORA_INVALID_SPREADING_FACTOR"
    if not 5 <= coding-rate <= 8:
      throw "LORA_INVALID_CODING_RATE"
    if not 4 <= preamble-length <= 65_535:
      throw "LORA_INVALID_PREAMBLE_LENGTH"
    if not 0 <= sync-word <= 0xff:
      throw "LORA_INVALID_SYNC_WORD"
    if not -9 <= tx-power <= 22:
      throw "LORA_INVALID_TX_POWER"

/**
Received LoRa packet and its measured link quality.
*/
class Packet:
  /** Received PHY payload. */
  payload/ByteArray

  /** Packet RSSI in dBm. */
  rssi/float

  /** Packet signal-to-noise ratio in dB. */
  snr/float

  constructor .payload .rssi .snr:

/**
Common blocking interface implemented by LoRa radios.
*/
interface Radio:
  /** Applies $configuration to the modem. */
  configure configuration/Configuration -> none

  /** Transmits one LoRa $payload. */
  transmit payload/io.Data -> none

  /**
  Waits for and receives one packet.

  Use $with-timeout around this call when a deadline is required.
  */
  receive -> Packet

  /** Puts the radio into standby mode. */
  standby -> none

  /** Puts the radio into its lowest-power sleep mode. */
  sleep -> none

  /** Leaves the radio in a safe low-power state. */
  close -> none
