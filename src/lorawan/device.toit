// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import .frames as frames
import .region as region

JOIN-ACCEPT-DELAY-MS ::= 5_000

/**
Radio boundary required by the LoRaWAN Class A state machine.

Applications adapt their concrete LoRa driver to this interface, keeping this
  package independent of SPI, GPIO, and any particular transceiver.
*/
interface Radio:
  /** Configures the radio for public-network LoRa using $parameters. */
  configure
      parameters/region.RadioParameters
      --tx-power/int
      --receive/bool=false
      -> none

  /** Transmits one complete LoRaWAN PHYPayload. */
  transmit payload/ByteArray -> none

  /**
  Receives a PHYPayload or returns null when no valid header is detected before
    $timeout-ms expires.

  Once a header is detected, the call may continue past $timeout-ms while the
    remainder of the packet is received.
  */
  receive --timeout-ms/int -> ByteArray?

/** Mutable LoRaWAN 1.0.x activation and frame-counter state. */
class Session:
  device-address/int
  network-session-key/ByteArray
  application-session-key/ByteArray
  uplink-counter/int := ?
  downlink-counter/int := ?

  constructor
      .device-address
      .network-session-key
      .application-session-key
      --uplink-counter/int=0
      --downlink-counter/int=0:
    this.uplink-counter = uplink-counter
    this.downlink-counter = downlink-counter

/**
Blocking LoRaWAN 1.0.x Class A end device.

The class implements ABP uplinks and OTAA joins with RX1 and RX2 windows. The
  caller is responsible for persisting session keys and both frame counters.
*/
class ClassA:
  radio_/Radio
  region_/region.Region
  session/Session? := null
  data-rate/int
  tx-power/int
  rx1-offset/int := ?
  rx2-data-rate/int? := ?
  receive-delay-ms/int := ?
  receive-window-ms/int

  constructor
      .radio_
      .region_
      --session/Session?=null
      --data-rate/int=0
      --tx-power/int=14
      --rx1-offset/int=0
      --rx2-data-rate/int?=null
      --receive-delay-ms/int=1_000
      --receive-window-ms/int=1_000:
    this.session = session
    this.data-rate = data-rate
    this.tx-power = tx-power
    this.rx1-offset = rx1-offset
    this.rx2-data-rate = rx2-data-rate
    this.receive-delay-ms = receive-delay-ms
    this.receive-window-ms = receive-window-ms

  /**
  Sends one Class A uplink and returns a valid downlink received in RX1 or RX2.
  */
  send
      payload/ByteArray
      --port/int=1
      --confirmed/bool=false
      --adr/bool=false
      -> frames.Downlink?:
    if not session: throw "LORAWAN_NOT_ACTIVATED"
    counter := session.uplink-counter
    uplink := region_.uplink counter data-rate
    if payload.size > uplink.max-payload-size: throw "LORAWAN_PAYLOAD_TOO_LARGE"
    frame := frames.build-uplink
        session.network-session-key
        session.application-session-key
        payload
        --device-address=session.device-address
        --frame-counter=counter
        --port=port
        --confirmed=confirmed
        --adr=adr
    radio_.configure uplink --tx-power=tx-power
    radio_.transmit frame
    session.uplink-counter++
    transmitted-at := Time.monotonic-us
    return receive-data-windows_ uplink transmitted-at

  /**
  Performs one OTAA join exchange and installs the resulting session.

  The caller must persist $device-nonce and increment it before every call.
    Reusing a nonce with the same $join-eui causes compliant Join Servers to
    reject the Join-Request.
  */
  join
      application-key/ByteArray
      join-eui/ByteArray
      device-eui/ByteArray
      device-nonce/int
      -> Session?:
    request := frames.build-join-request
        application-key
        join-eui
        device-eui
        device-nonce
    uplink := region_.uplink device-nonce data-rate
    radio_.configure uplink --tx-power=tx-power
    radio_.transmit request
    transmitted-at := Time.monotonic-us
    response := receive-raw-windows_
        uplink
        transmitted-at
        JOIN-ACCEPT-DELAY-MS
    if not response: return null
    accepted := frames.parse-join-accept application-key response device-nonce
    rx1-offset = accepted.rx1-offset
    rx2-data-rate = accepted.rx2-data-rate
    receive-delay-ms = accepted.receive-delay-seconds * 1_000
    session = Session
        accepted.device-address
        accepted.network-session-key
        accepted.application-session-key
    return session

  receive-data-windows_
      uplink/region.RadioParameters
      transmitted-at/int
      -> frames.Downlink?:
    frame := receive-raw-windows_ uplink transmitted-at receive-delay-ms
    if not frame: return null
    counter := reconstruct-counter_ session.downlink-counter frame
    downlink := frames.parse-downlink
        session.network-session-key
        session.application-session-key
        frame
        --device-address=session.device-address
        --frame-counter=counter
    session.downlink-counter = counter + 1
    return downlink

  receive-raw-windows_
      uplink/region.RadioParameters
      transmitted-at/int
      delay-ms/int
      -> ByteArray?:
    first := region_.rx1 uplink.channel data-rate rx1-offset
    radio_.configure first --tx-power=tx-power --receive
    wait-until_ transmitted-at + delay-ms * 1_000
    frame := radio_.receive --timeout-ms=receive-window-ms
    if frame: return frame
    second := region_.rx2 --data-rate=rx2-data-rate
    radio_.configure second --tx-power=tx-power --receive
    wait-until_ transmitted-at + (delay-ms + 1_000) * 1_000
    return radio_.receive --timeout-ms=receive-window-ms

  static reconstruct-counter_ expected/int frame/ByteArray -> int:
    if frame.size < 8: throw "LORAWAN_DOWNLINK_TOO_SHORT"
    low := frame[6] | (frame[7] << 8)
    candidate := (expected & 0xffff_0000) | low
    if candidate < expected: candidate += 0x1_0000
    return candidate

  static wait-until_ deadline/int -> none:
    remaining := deadline - Time.monotonic-us
    if remaining > 0: sleep (Duration --us=remaining)
