// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import gpio
import io
import monitor
import spi

import .radio as radio

/**
Driver for Semtech SX1276, SX1277, SX1278, and SX1279 LoRa radios.

The caller owns the SPI device. The driver owns its GPIO pins and releases them
  when closed.
*/
class Sx127x implements radio.Radio:
  static REG-FIFO_ ::= 0x00
  static REG-OP-MODE_ ::= 0x01
  static REG-FRF-MSB_ ::= 0x06
  static REG-PA-CONFIG_ ::= 0x09
  static REG-OCP_ ::= 0x0b
  static REG-LNA_ ::= 0x0c
  static REG-FIFO-ADDR-PTR_ ::= 0x0d
  static REG-FIFO-TX-BASE-ADDR_ ::= 0x0e
  static REG-FIFO-RX-BASE-ADDR_ ::= 0x0f
  static REG-FIFO-RX-CURRENT-ADDR_ ::= 0x10
  static REG-IRQ-FLAGS_ ::= 0x12
  static REG-RX-NB-BYTES_ ::= 0x13
  static REG-PKT-SNR-VALUE_ ::= 0x19
  static REG-PKT-RSSI-VALUE_ ::= 0x1a
  static REG-MODEM-CONFIG-1_ ::= 0x1d
  static REG-MODEM-CONFIG-2_ ::= 0x1e
  static REG-PREAMBLE-MSB_ ::= 0x20
  static REG-PAYLOAD-LENGTH_ ::= 0x22
  static REG-MODEM-CONFIG-3_ ::= 0x26
  static REG-DETECTION-OPTIMIZE_ ::= 0x31
  static REG-INVERT-IQ_ ::= 0x33
  static REG-DETECTION-THRESHOLD_ ::= 0x37
  static REG-INVERT-IQ-2_ ::= 0x3b
  static REG-SYNC-WORD_ ::= 0x39
  static REG-DIO-MAPPING-1_ ::= 0x40
  static REG-VERSION_ ::= 0x42
  static REG-PA-DAC_ ::= 0x4d

  static LONG-RANGE-MODE_ ::= 0x80
  static MODE-SLEEP_ ::= 0x00
  static MODE-STANDBY_ ::= 0x01
  static MODE-TX_ ::= 0x03
  static MODE-RX-CONTINUOUS_ ::= 0x05

  static IRQ-RX-DONE_ ::= 1 << 6
  static IRQ-PAYLOAD-CRC-ERROR_ ::= 1 << 5
  static IRQ-VALID-HEADER_ ::= 1 << 4
  static IRQ-TX-DONE_ ::= 1 << 3

  device_/spi.Device
  reset_/gpio.Pin? := null
  dio0_/gpio.Pin? := null
  mutex_/monitor.Mutex ::= monitor.Mutex
  configuration_/radio.Configuration := radio.Configuration
  closed_/bool := false

  /**
  Constructs and probes an SX127x attached to $device.

  The optional $reset and $dio0 pin numbers are opened and owned by the driver.
    Polling is used when $dio0 is absent.
  */
  constructor device/spi.Device --reset/int?=null --dio0/int?=null:
    device_ = device
    succeeded := false
    try:
      if reset: reset_ = gpio.Pin reset
      if dio0: dio0_ = gpio.Pin dio0
      if reset_:
        reset_.configure --output --value=1
        reset-radio_
      if dio0_: dio0_.configure --input
      version := read-register_ REG-VERSION_
      if version != 0x12: throw "SX127X_BAD_VERSION"
      set-mode_ MODE-SLEEP_
      sleep-ms_ 1
      write-register_ REG-FIFO-TX-BASE-ADDR_ 0
      write-register_ REG-FIFO-RX-BASE-ADDR_ 0
      write-register_ REG-LNA_ ((read-register_ REG-LNA_) | 0x03)
      configure configuration_
      succeeded = true
    finally:
      if not succeeded: close-pins_

  /** See $radio.Radio.configure. */
  configure configuration/radio.Configuration -> none:
    configuration.validate
    mutex_.do:
      ensure-open_
      set-mode_ MODE-STANDBY_
      set-frequency_ configuration.frequency
      set-bandwidth-and-coding-rate_
          configuration.bandwidth
          configuration.coding-rate
      set-spreading-factor_ configuration.spreading-factor
      modem-config-2 := read-register_ REG-MODEM-CONFIG-2_
      if configuration.crc:
        modem-config-2 |= 0x04
      else:
        modem-config-2 &= 0xfb
      write-register_ REG-MODEM-CONFIG-2_ modem-config-2
      write-register-16_ REG-PREAMBLE-MSB_ configuration.preamble-length
      write-register_ REG-SYNC-WORD_ configuration.sync-word
      write-register_ REG-INVERT-IQ_ (configuration.invert-iq ? 0x67 : 0x27)
      write-register_ REG-INVERT-IQ-2_ (configuration.invert-iq ? 0x19 : 0x1d)
      write-register_ 0x24 0x00
      set-low-data-rate-optimize_
          configuration.bandwidth
          configuration.spreading-factor
      set-tx-power_ configuration.tx-power
      configuration_ = configuration

  /** See $radio.Radio.transmit. */
  transmit payload/io.Data -> none:
    if payload.byte-size > radio.MAX-PAYLOAD-SIZE:
      throw "LORA_PAYLOAD_TOO_LARGE"
    mutex_.do:
      ensure-open_
      set-mode_ MODE-STANDBY_
      write-register_ REG-DIO-MAPPING-1_ 0x40
      write-register_ REG-IRQ-FLAGS_ 0xff
      write-register_ REG-FIFO-ADDR-PTR_ 0
      write-burst_ REG-FIFO_ payload
      write-register_ REG-PAYLOAD-LENGTH_ payload.byte-size
      set-mode_ MODE-TX_
      try:
        wait-for-irq_ IRQ-TX-DONE_
      finally:
        write-register_ REG-IRQ-FLAGS_ 0xff
        set-mode_ MODE-STANDBY_

  /** See $radio.Radio.receive. */
  receive -> radio.Packet:
    return mutex_.do:
      ensure-open_
      write-register_ REG-DIO-MAPPING-1_ 0x00
      write-register_ REG-IRQ-FLAGS_ 0xff
      set-mode_ MODE-RX-CONTINUOUS_
      try:
        while true:
          irq := read-register_ REG-IRQ-FLAGS_
          if (irq & IRQ-VALID-HEADER_) != 0:
            write-register_ REG-IRQ-FLAGS_ IRQ-VALID-HEADER_
          if (irq & IRQ-RX-DONE_) != 0:
            write-register_ REG-IRQ-FLAGS_ irq
            if (irq & IRQ-PAYLOAD-CRC-ERROR_) != 0:
              continue
            size := read-register_ REG-RX-NB-BYTES_
            address := read-register_ REG-FIFO-RX-CURRENT-ADDR_
            write-register_ REG-FIFO-ADDR-PTR_ address
            payload := read-burst_ REG-FIFO_ size
            snr-raw := signed-byte_ (read-register_ REG-PKT-SNR-VALUE_)
            snr := snr-raw.to-float / 4.0
            rssi-offset := configuration_.frequency < 779_000_000 ? -164.0 : -157.0
            rssi := rssi-offset + (read-register_ REG-PKT-RSSI-VALUE_).to-float
            if snr < 0: rssi += snr
            return radio.Packet payload rssi snr
          sleep-ms_ 1
      finally:
        set-mode_ MODE-STANDBY_

  /** See $radio.Radio.standby. */
  standby -> none:
    mutex_.do:
      ensure-open_
      set-mode_ MODE-STANDBY_

  /** See $radio.Radio.sleep. */
  sleep -> none:
    mutex_.do:
      ensure-open_
      set-mode_ MODE-SLEEP_

  /** See $radio.Radio.close. */
  close -> none:
    if closed_: return
    mutex_.do:
      if closed_: return
      try:
        set-mode_ MODE-SLEEP_
      finally:
        closed_ = true
        close-pins_

  close-pins_ -> none:
    if dio0_:
      dio0_.close
      dio0_ = null
    if reset_:
      reset_.close
      reset_ = null

  reset-radio_ -> none:
    reset_.set 0
    sleep-ms_ 2
    reset_.set 1
    sleep-ms_ 10

  ensure-open_ -> none:
    if closed_: throw "LORA_CLOSED"

  set-mode_ mode/int -> none:
    write-register_ REG-OP-MODE_ (LONG-RANGE-MODE_ | mode)

  set-frequency_ frequency/int -> none:
    frf := (frequency << 19) / 32_000_000
    write-register_ REG-FRF-MSB_ (frf >> 16)
    write-register_ REG-FRF-MSB_ + 1 (frf >> 8)
    write-register_ REG-FRF-MSB_ + 2 frf

  set-bandwidth-and-coding-rate_ bandwidth/int coding-rate/int -> none:
    bandwidth-code := bandwidth-code_ bandwidth
    value := (bandwidth-code << 4) | ((coding-rate - 4) << 1)
    write-register_ REG-MODEM-CONFIG-1_ value

  set-spreading-factor_ spreading-factor/int -> none:
    write-register_ REG-DETECTION-OPTIMIZE_ 0xc3
    write-register_ REG-DETECTION-THRESHOLD_ 0x0a
    value := read-register_ REG-MODEM-CONFIG-2_
    write-register_ REG-MODEM-CONFIG-2_
        ((value & 0x0f) | (spreading-factor << 4))

  set-low-data-rate-optimize_ bandwidth/int spreading-factor/int -> none:
    symbol-us := ((1 << spreading-factor) * 1_000_000) / bandwidth
    value := 0x04
    if symbol-us > 16_000: value |= 0x08
    write-register_ REG-MODEM-CONFIG-3_ value

  set-tx-power_ power/int -> none:
    if power < 2: power = 2
    if power > 20: power = 20
    if power > 17:
      write-register_ REG-PA-DAC_ 0x87
      set-over-current-protection_ 140
      power -= 3
    else:
      write-register_ REG-PA-DAC_ 0x84
      set-over-current-protection_ 100
    write-register_ REG-PA-CONFIG_ (0xf0 | (power - 2))

  set-over-current-protection_ milliamps/int -> none:
    trim := milliamps <= 120
        ? (milliamps - 45) / 5
        : (milliamps + 30) / 10
    write-register_ REG-OCP_ (0x20 | (trim & 0x1f))

  wait-for-irq_ mask/int -> none:
    while ((read-register_ REG-IRQ-FLAGS_) & mask) == 0:
      if dio0_:
        dio0_.wait-for 1
      else:
        sleep-ms_ 1

  read-register_ address/int -> int:
    data := #[address & 0x7f, 0]
    device_.transfer data --read
    return data[1]

  write-register_ address/int value/int -> none:
    device_.write #[address | 0x80, value & 0xff]

  write-register-16_ address/int value/int -> none:
    device_.write #[address | 0x80, (value >> 8) & 0xff, value & 0xff]

  write-burst_ address/int data/io.Data -> none:
    command := ByteArray (data.byte-size + 1)
    command[0] = address | 0x80
    data.write-to-byte-array command --at=1 0 data.byte-size
    device_.write command

  read-burst_ address/int size/int -> ByteArray:
    command := ByteArray (size + 1)
    command[0] = address & 0x7f
    device_.transfer command --read
    return command[1..]

  static bandwidth-code_ bandwidth/int -> int:
    if bandwidth == 7_800: return 0
    if bandwidth == 10_400: return 1
    if bandwidth == 15_600: return 2
    if bandwidth == 20_800: return 3
    if bandwidth == 31_250: return 4
    if bandwidth == 41_700: return 5
    if bandwidth == 62_500: return 6
    if bandwidth == 125_000: return 7
    if bandwidth == 250_000: return 8
    if bandwidth == 500_000: return 9
    throw "LORA_INVALID_BANDWIDTH"

  static signed-byte_ value/int -> int:
    return value >= 0x80 ? value - 0x100 : value

sleep-ms_ milliseconds/int -> none:
  sleep --ms=milliseconds
