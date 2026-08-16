// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

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
      --frequency/int=868_100_000
      --bandwidth/int=125_000
      --spreading-factor/int=7
      --coding-rate/int=5
      --preamble-length/int=8
      --crc/bool=true
      --invert-iq/bool=false
      --sync-word/int=PRIVATE-SYNC-WORD
      --tx-power/int=14:
    this.frequency = frequency
    this.bandwidth = bandwidth
    this.spreading-factor = spreading-factor
    this.coding-rate = coding-rate
    this.preamble-length = preamble-length
    this.crc = crc
    this.invert-iq = invert-iq
    this.sync-word = sync-word
    this.tx-power = tx-power
    validate

  /** Validates this configuration. */
  validate -> none:
    if frequency < 137_000_000 or frequency > 1_020_000_000:
      throw "LORA_INVALID_FREQUENCY"
    if spreading-factor < 7 or spreading-factor > 12:
      throw "LORA_INVALID_SPREADING_FACTOR"
    if coding-rate < 5 or coding-rate > 8:
      throw "LORA_INVALID_CODING_RATE"
    if preamble-length < 4 or preamble-length > 65_535:
      throw "LORA_INVALID_PREAMBLE_LENGTH"
    if sync-word < 0 or sync-word > 0xff:
      throw "LORA_INVALID_SYNC_WORD"
    if tx-power < -9 or tx-power > 22:
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
  transmit payload/ByteArray -> none

  /**
  Receives one packet, or returns null when no valid header is detected before
    $timeout-ms expires.

  Once a header is detected, the call may continue past $timeout-ms while the
    remainder of the packet is received. A negative timeout waits indefinitely.
  */
  receive --timeout-ms/int=-1 -> Packet?

  /** Puts the radio into standby mode. */
  standby -> none

  /** Puts the radio into its lowest-power sleep mode. */
  sleep-radio -> none

  /** Leaves the radio in a safe low-power state. */
  close -> none

maximum-packet-airtime-us_ configuration/Configuration -> int:
  symbol-us :=
      (((1 << configuration.spreading-factor) * 1_000_000)
          + configuration.bandwidth - 1) / configuration.bandwidth
  low-data-rate-optimize := symbol-us > 16_000 ? 1 : 0
  numerator :=
      8 * MAX-PAYLOAD-SIZE
          - 4 * configuration.spreading-factor
          + 28
          + (configuration.crc ? 16 : 0)
  denominator := 4 * (configuration.spreading-factor
      - 2 * low-data-rate-optimize)
  encoded-blocks := numerator <= 0
      ? 0
      : (numerator + denominator - 1) / denominator
  payload-symbols := 8 + encoded-blocks * configuration.coding-rate
  quarter-symbols :=
      4 * configuration.preamble-length + 17 + 4 * payload-symbols
  return (quarter-symbols * symbol-us + 3) / 4
