// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

/** LoRaWAN radio settings for one channel and data rate. */
class RadioParameters:
  channel/int
  frequency/int
  bandwidth/int
  spreading-factor/int
  max-payload-size/int

  constructor .channel .frequency .bandwidth .spreading-factor .max-payload-size:

/** Regional channel-plan operations needed by a Class A end device. */
interface Region:
  /** Selects uplink settings for $frame-counter and $data-rate. */
  uplink frame-counter/int data-rate/int -> RadioParameters

  /** Computes RX1 settings from the uplink channel and data rate. */
  rx1 uplink-channel/int data-rate/int offset/int -> RadioParameters

  /** Returns RX2 settings, optionally overriding the default $data-rate. */
  rx2 --data-rate/int?=null -> RadioParameters

/** EU863-870 regional channel plan. */
class Eu868 implements Region:
  static CHANNELS_ ::= [868_100_000, 868_300_000, 868_500_000]

  /** See $Region.uplink. */
  uplink frame-counter/int data-rate/int -> RadioParameters:
    frequency := CHANNELS_[frame-counter % CHANNELS_.size]
    return parameters_ (frame-counter % CHANNELS_.size) frequency data-rate

  /** See $Region.rx1. */
  rx1 uplink-channel/int data-rate/int offset/int -> RadioParameters:
    frequency := CHANNELS_[uplink-channel % CHANNELS_.size]
    return parameters_
        (uplink-channel % CHANNELS_.size)
        frequency
        (max 0 (data-rate - offset))

  /** See $Region.rx2. */
  rx2 --data-rate/int?=null -> RadioParameters:
    return parameters_ 0 869_525_000 (data-rate or 0)

  static parameters_ channel/int frequency/int data-rate/int -> RadioParameters:
    if data-rate < 0 or data-rate > 6: throw "LORAWAN_INVALID_DATA_RATE"
    spreading-factor := data-rate <= 5 ? 12 - data-rate : 7
    bandwidth := data-rate == 6 ? 250_000 : 125_000
    max-payload := data-rate <= 2 ? 51 : (data-rate == 3 ? 115 : 242)
    return RadioParameters channel frequency bandwidth spreading-factor max-payload

/** US902-928 regional channel plan. */
class Us915 implements Region:
  /** See $Region.uplink. */
  uplink frame-counter/int data-rate/int -> RadioParameters:
    if data-rate < 0 or data-rate > 4: throw "LORAWAN_INVALID_DATA_RATE"
    if data-rate == 4:
      channel := frame-counter % 8
      return RadioParameters channel (903_000_000 + channel * 1_600_000) 500_000 8 242
    channel := frame-counter % 64
    spreading-factor := 10 - data-rate
    max-payload := data-rate == 0
        ? 11
        : (data-rate == 1 ? 53 : (data-rate == 2 ? 125 : 242))
    return RadioParameters
        channel
        (902_300_000 + channel * 200_000)
        125_000
        spreading-factor
        max-payload

  /** See $Region.rx1. */
  rx1 uplink-channel/int data-rate/int offset/int -> RadioParameters:
    downlink-data-rate := 10 + data-rate - offset
    downlink-data-rate = max 8 (min 13 downlink-data-rate)
    spreading-factors := [12, 11, 10, 9, 8, 7]
    spreading-factor := spreading-factors[downlink-data-rate - 8]
    frequency := 923_300_000 + (uplink-channel % 8) * 600_000
    return RadioParameters (uplink-channel % 8) frequency 500_000 spreading-factor 242

  /** See $Region.rx2. */
  rx2 --data-rate/int?=null -> RadioParameters:
    effective-data-rate := data-rate or 8
    if effective-data-rate < 8 or effective-data-rate > 13:
      throw "LORAWAN_INVALID_DATA_RATE"
    spreading-factors := [12, 11, 10, 9, 8, 7]
    return RadioParameters
        0
        923_300_000
        500_000
        spreading-factors[effective-data-rate - 8]
        242
