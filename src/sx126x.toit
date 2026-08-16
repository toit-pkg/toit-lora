// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import gpio
import io
import monitor
import spi

import .radio as radio

/**
Driver implementation for the Semtech SX1262 LoRa radio.

The caller owns the SPI device. The driver owns its GPIO pins and releases them
  when closed.
*/
class Sx1262 implements radio.Radio:
  static TX-TIMEOUT-MS_ ::= 15_000
  static TX-IRQ-GUARD-MS_ ::= 100
  static BUSY-TIMEOUT-MS_ ::= 1_000

  static SET-SLEEP_ ::= 0x84
  static SET-STANDBY_ ::= 0x80
  static SET-TX_ ::= 0x83
  static SET-RX_ ::= 0x82
  static SET-RF-FREQUENCY_ ::= 0x86
  static CALIBRATE_ ::= 0x89
  static CALIBRATE-IMAGE_ ::= 0x98
  static SET-REGULATOR-MODE_ ::= 0x96
  static SET-PA-CONFIG_ ::= 0x95
  static SET-RX-TX-FALLBACK-MODE_ ::= 0x93
  static WRITE-REGISTER_ ::= 0x0d
  static READ-REGISTER_ ::= 0x1d
  static WRITE-BUFFER_ ::= 0x0e
  static READ-BUFFER_ ::= 0x1e
  static SET-DIO-IRQ-PARAMS_ ::= 0x08
  static GET-IRQ-STATUS_ ::= 0x12
  static CLEAR-IRQ-STATUS_ ::= 0x02
  static SET-DIO2-AS-RF-SWITCH-CTRL_ ::= 0x9d
  static SET-DIO3-AS-TCXO-CTRL_ ::= 0x97
  static SET-PACKET-TYPE_ ::= 0x8a
  static SET-TX-PARAMS_ ::= 0x8e
  static SET-MODULATION-PARAMS_ ::= 0x8b
  static SET-PACKET-PARAMS_ ::= 0x8c
  static SET-BUFFER-BASE-ADDRESS_ ::= 0x8f
  static GET-RX-BUFFER-STATUS_ ::= 0x13
  static GET-PACKET-STATUS_ ::= 0x14
  static GET-STATUS_ ::= 0xc0

  static PACKET-TYPE-LORA_ ::= 0x01
  static STANDBY-RC_ ::= 0x00
  static FALLBACK-STANDBY-RC_ ::= 0x20

  static IRQ-TX-DONE_ ::= 1 << 0
  static IRQ-RX-DONE_ ::= 1 << 1
  static IRQ-HEADER-VALID_ ::= 1 << 4
  static IRQ-HEADER-ERROR_ ::= 1 << 5
  static IRQ-CRC-ERROR_ ::= 1 << 6
  static IRQ-TIMEOUT_ ::= 1 << 9
  static IRQ-ALL_ ::= 0x03ff

  static REG-LORA-SYNC-WORD-MSB_ ::= 0x0740
  static REG-TX-CLAMP-CONFIG_ ::= 0x08d8
  static REG-OCP-CONFIG_ ::= 0x08e7

  device_/spi.Device
  busy_/gpio.Pin
  reset_/gpio.Pin? := null
  dio1_/gpio.Pin? := null
  mutex_/monitor.Mutex ::= monitor.Mutex
  configuration_/radio.Configuration := radio.Configuration
  calibrated-band_/int := -1
  closed_/bool := false

  /**
  Constructs and probes an SX126x attached to $device.

  The $busy pin number is mandatory. The optional $reset and $dio1 pin numbers
    are opened and owned by the driver. $tcxo-voltage selects the
    DIO3-controlled TCXO voltage in millivolts; zero disables DIO3 TCXO control.
    $dio2-rf-switch enables the radio's automatic RF switch.
  */
  constructor
      device/spi.Device
      busy/int
      --reset/int?=null
      --dio1/int?=null
      --tcxo-voltage/int=0
      --dio2-rf-switch/bool=false:
    device_ = device
    busy_ = gpio.Pin busy
    succeeded := false
    try:
      if reset: reset_ = gpio.Pin reset
      if dio1: dio1_ = gpio.Pin dio1
      busy_.configure --input
      if dio1_: dio1_.configure --input
      if reset_:
        reset_.configure --output --value=1
        reset-radio_
      wait-while-busy_
      status := get-status_
      if status == 0 or status == 0xff: throw "SX126X_NOT_FOUND"
      if tcxo-voltage > 0: configure-tcxo_ tcxo-voltage
      write-command_ SET-STANDBY_ #[STANDBY-RC_]
      write-command_ SET-REGULATOR-MODE_ #[0x01]
      write-command_ CALIBRATE_ #[0x7f]
      if dio2-rf-switch:
        write-command_ SET-DIO2-AS-RF-SWITCH-CTRL_ #[0x01]
      write-command_ SET-PACKET-TYPE_ #[PACKET-TYPE-LORA_]
      write-command_ SET-BUFFER-BASE-ADDRESS_ #[0x00, 0x00]
      write-command_ SET-RX-TX-FALLBACK-MODE_ #[FALLBACK-STANDBY-RC_]
      clamp := read-register-byte_ REG-TX-CLAMP-CONFIG_
      write-register-byte_ REG-TX-CLAMP-CONFIG_ (clamp | 0x1e)
      write-register-byte_ REG-OCP-CONFIG_ 0x38
      configure configuration_
      succeeded = true
    finally:
      if not succeeded: close-pins_

  /** See $radio.Radio.configure. */
  configure configuration/radio.Configuration -> none:
    configuration.validate
    if not 150_000_000 <= configuration.frequency <= 960_000_000:
      throw "SX126X_INVALID_FREQUENCY"
    if not -9 <= configuration.tx-power <= 22:
      throw "SX126X_INVALID_TX_POWER"
    mutex_.do:
      ensure-open_
      write-command_ SET-STANDBY_ #[STANDBY-RC_]
      calibrate-image_ configuration.frequency
      set-frequency_ configuration.frequency
      set-modulation-parameters_ configuration
      set-packet-parameters_ configuration radio.MAX-PAYLOAD-SIZE
      set-sync-word_ configuration.sync-word
      set-tx-power_ configuration.tx-power
      clear-irq_ IRQ-ALL_
      configuration_ = configuration

  /** See $radio.Radio.transmit. */
  transmit payload/io.Data -> none:
    if payload.byte-size > radio.MAX-PAYLOAD-SIZE:
      throw "LORA_PAYLOAD_TOO_LARGE"
    mutex_.do:
      ensure-open_
      write-command_ SET-STANDBY_ #[STANDBY-RC_]
      set-packet-parameters_ configuration_ payload.byte-size
      write-buffer_ 0 payload
      irq-mask := IRQ-TX-DONE_ | IRQ-TIMEOUT_
      set-irq-mapping_ irq-mask irq-mask
      clear-irq_ IRQ-ALL_
      timeout := timeout-units_ TX-TIMEOUT-MS_
      write-command_ SET-TX_ (uint24_ timeout)
      try:
        deadline-us := Time.monotonic-us
            + (TX-TIMEOUT-MS_ + TX-IRQ-GUARD-MS_) * 1_000
        irq := wait-for-irq_ irq-mask --deadline-us=deadline-us
        if (irq & IRQ-TX-DONE_) == 0: throw "LORA_TX_TIMEOUT"
      finally:
        clear-irq_ IRQ-ALL_
        write-command_ SET-STANDBY_ #[STANDBY-RC_]

  /** See $radio.Radio.receive. */
  receive --timeout-ms/int?=null -> radio.Packet?:
    return mutex_.do:
      ensure-open_
      write-command_ SET-STANDBY_ #[STANDBY-RC_]
      set-packet-parameters_ configuration_ radio.MAX-PAYLOAD-SIZE
      irq-mask := IRQ-RX-DONE_
          | IRQ-HEADER-VALID_
          | IRQ-HEADER-ERROR_
          | IRQ-CRC-ERROR_
          | IRQ-TIMEOUT_
      set-irq-mapping_ irq-mask irq-mask
      clear-irq_ IRQ-ALL_
      write-command_ SET-RX_ (uint24_ 0xffffff)
      deadline := timeout-ms and (Time.monotonic-us + timeout-ms * 1_000)
      try:
        while true:
          irq := wait-for-irq_ irq-mask --deadline-us=deadline
          if (irq & (IRQ-TIMEOUT_ | IRQ-HEADER-ERROR_ | IRQ-CRC-ERROR_)) != 0:
            return null
          if (irq & IRQ-HEADER-VALID_) != 0:
            clear-irq_ IRQ-HEADER-VALID_
            if deadline:
              deadline = Time.monotonic-us +
                  (radio.maximum-packet-airtime-us_ configuration_)
          if (irq & IRQ-RX-DONE_) != 0:
            status := read-command_ GET-RX-BUFFER-STATUS_ #[] 2
            payload := read-buffer_ status[1] status[0]
            packet-status := read-command_ GET-PACKET-STATUS_ #[] 3
            rssi := -packet-status[0].to-float / 2.0
            snr := signed-byte_ packet-status[1]
            return radio.Packet payload rssi (snr.to-float / 4.0)
      finally:
        clear-irq_ IRQ-ALL_
        write-command_ SET-STANDBY_ #[STANDBY-RC_]

  /** See $radio.Radio.standby. */
  standby -> none:
    mutex_.do:
      ensure-open_
      write-command_ SET-STANDBY_ #[STANDBY-RC_]

  /** See $radio.Radio.sleep. */
  sleep -> none:
    mutex_.do:
      ensure-open_
      write-command_ SET-SLEEP_ #[0x00] --wait=false

  /** See $radio.Radio.close. */
  close -> none:
    if closed_: return
    mutex_.do:
      if closed_: return
      try:
        write-command_ SET-SLEEP_ #[0x00] --wait=false
      finally:
        closed_ = true
        close-pins_

  close-pins_ -> none:
    if dio1_: dio1_.close
    if reset_: reset_.close
    busy_.close

  reset-radio_ -> none:
    reset_.set 0
    sleep-ms_ 2
    reset_.set 1
    sleep-ms_ 10

  ensure-open_ -> none:
    if closed_: throw "LORA_CLOSED"

  get-status_ -> int:
    data := #[GET-STATUS_, 0x00]
    device_.transfer data --read
    return data[1]

  configure-tcxo_ millivolts/int -> none:
    voltage-code := tcxo-voltage-code_ millivolts
    delay := timeout-units_ 5
    write-command_ SET-DIO3-AS-TCXO-CTRL_
        #[voltage-code, (delay >> 16) & 0xff, (delay >> 8) & 0xff, delay & 0xff]

  set-frequency_ frequency/int -> none:
    value := (frequency << 25) / 32_000_000
    write-command_ SET-RF-FREQUENCY_
        #[
          (value >> 24) & 0xff,
          (value >> 16) & 0xff,
          (value >> 8) & 0xff,
          value & 0xff,
        ]

  set-modulation-parameters_ configuration/radio.Configuration -> none:
    symbol-us := ((1 << configuration.spreading-factor) * 1_000_000) / configuration.bandwidth
    low-data-rate-optimize := symbol-us > 16_000 ? 1 : 0
    write-command_ SET-MODULATION-PARAMS_
        #[
          configuration.spreading-factor,
          bandwidth-code_ configuration.bandwidth,
          configuration.coding-rate - 4,
          low-data-rate-optimize,
        ]

  set-packet-parameters_ configuration/radio.Configuration payload-size/int -> none:
    write-command_ SET-PACKET-PARAMS_
        #[
          (configuration.preamble-length >> 8) & 0xff,
          configuration.preamble-length & 0xff,
          0x00,
          payload-size,
          configuration.crc ? 0x01 : 0x00,
          configuration.invert-iq ? 0x01 : 0x00,
        ]

  set-sync-word_ sync-word/int -> none:
    first := (sync-word & 0xf0) | 0x04
    second := ((sync-word & 0x0f) << 4) | 0x04
    write-register_ REG-LORA-SYNC-WORD-MSB_ #[first, second]

  set-tx-power_ power/int -> none:
    write-command_ SET-PA-CONFIG_ #[0x04, 0x07, 0x00, 0x01]
    write-command_ SET-TX-PARAMS_ #[power & 0xff, 0x04]

  calibrate-image_ frequency/int -> none:
    band := image-calibration-band_ frequency
    if band == calibrated-band_: return
    values := image-calibration-values_ band
    write-command_ CALIBRATE-IMAGE_ values
    calibrated-band_ = band

  set-irq-mapping_ mask/int dio1-mask/int -> none:
    write-command_ SET-DIO-IRQ-PARAMS_
        #[
          (mask >> 8) & 0xff,
          mask & 0xff,
          (dio1-mask >> 8) & 0xff,
          dio1-mask & 0xff,
          0x00,
          0x00,
          0x00,
          0x00,
        ]

  get-irq_ -> int:
    data := read-command_ GET-IRQ-STATUS_ #[] 2
    return (data[0] << 8) | data[1]

  clear-irq_ mask/int -> none:
    write-command_ CLEAR-IRQ-STATUS_ #[(mask >> 8) & 0xff, mask & 0xff]

  wait-for-irq_ mask/int --deadline-us/int?=null -> int:
    while true:
      irq := get-irq_
      if (irq & mask) != 0: return irq
      if deadline-us and Time.monotonic-us >= deadline-us:
        return IRQ-TIMEOUT_
      if dio1_:
        if deadline-us:
          remaining := deadline-us - Time.monotonic-us
          if remaining <= 0: return IRQ-TIMEOUT_
          exception := catch --unwind=(: it != DEADLINE-EXCEEDED-ERROR):
            with-timeout --us=remaining: dio1_.wait-for 1
          if exception: return IRQ-TIMEOUT_
        else:
          dio1_.wait-for 1
      else:
        sleep-ms_ 1
    unreachable

  wait-while-busy_ -> none:
    if busy_.get == 0: return
    exception := catch --unwind=(: it != DEADLINE-EXCEEDED-ERROR):
      with-timeout --ms=BUSY-TIMEOUT-MS_: busy_.wait-for 0
    if exception: throw "SX126X_BUSY_TIMEOUT"

  write-command_ -> none
      opcode/int
      data/ByteArray
      --wait/bool=true:
    wait-while-busy_
    command := ByteArray (data.size + 1)
    command[0] = opcode
    command.replace 1 data
    device_.write command
    if wait: wait-while-busy_

  read-command_ opcode/int header/ByteArray response-size/int -> ByteArray:
    wait-while-busy_
    response-offset := 1 + header.size + 1
    command := ByteArray (response-offset + response-size)
    command[0] = opcode
    command.replace 1 header
    device_.transfer command --read
    wait-while-busy_
    return command[response-offset..]

  write-register_ address/int data/ByteArray -> none:
    command := ByteArray (data.size + 2)
    command[0] = (address >> 8) & 0xff
    command[1] = address & 0xff
    command.replace 2 data
    write-command_ WRITE-REGISTER_ command

  write-register-byte_ address/int value/int -> none:
    write-register_ address #[value & 0xff]

  read-register_ address/int size/int -> ByteArray:
    return read-command_ READ-REGISTER_
        #[(address >> 8) & 0xff, address & 0xff]
        size

  read-register-byte_ address/int -> int:
    return (read-register_ address 1)[0]

  write-buffer_ offset/int data/io.Data -> none:
    command := ByteArray (data.byte-size + 1)
    command[0] = offset
    data.write-to-byte-array command --at=1 0 data.byte-size
    write-command_ WRITE-BUFFER_ command

  read-buffer_ offset/int size/int -> ByteArray:
    return read-command_ READ-BUFFER_ #[offset] size

  static timeout-units_ milliseconds/int -> int:
    if milliseconds <= 0: return 1
    units := milliseconds * 64
    return min units 0xffffff

  static uint24_ value/int -> ByteArray:
    return #[(value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff]

  static bandwidth-code_ bandwidth/int -> int:
    if bandwidth == 7_800: return 0x00
    if bandwidth == 10_400: return 0x08
    if bandwidth == 15_600: return 0x01
    if bandwidth == 20_800: return 0x09
    if bandwidth == 31_250: return 0x02
    if bandwidth == 41_700: return 0x0a
    if bandwidth == 62_500: return 0x03
    if bandwidth == 125_000: return 0x04
    if bandwidth == 250_000: return 0x05
    if bandwidth == 500_000: return 0x06
    throw "LORA_INVALID_BANDWIDTH"

  static tcxo-voltage-code_ millivolts/int -> int:
    if millivolts == 1_600: return 0
    if millivolts == 1_700: return 1
    if millivolts == 1_800: return 2
    if millivolts == 2_200: return 3
    if millivolts == 2_400: return 4
    if millivolts == 2_700: return 5
    if millivolts == 3_000: return 6
    if millivolts == 3_300: return 7
    throw "SX126X_INVALID_TCXO_VOLTAGE"

  static image-calibration-band_ frequency/int -> int:
    if 430_000_000 <= frequency <= 440_000_000: return 0
    if 470_000_000 <= frequency <= 510_000_000: return 1
    if 779_000_000 <= frequency <= 787_000_000: return 2
    if 863_000_000 <= frequency <= 870_000_000: return 3
    if 902_000_000 <= frequency <= 928_000_000: return 4
    throw "SX126X_UNSUPPORTED_CALIBRATION_BAND"

  static image-calibration-values_ band/int -> ByteArray:
    if band == 0: return #[0x6b, 0x6f]
    if band == 1: return #[0x75, 0x81]
    if band == 2: return #[0xc1, 0xc5]
    if band == 3: return #[0xd7, 0xdb]
    if band == 4: return #[0xe1, 0xe9]
    unreachable

  static signed-byte_ value/int -> int:
    return value >= 0x80 ? value - 0x100 : value

sleep-ms_ milliseconds/int -> none:
  sleep --ms=milliseconds
