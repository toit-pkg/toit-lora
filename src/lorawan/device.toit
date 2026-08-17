// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import io

import ..radio as lora
import .frames as frames
import .region as region

JOIN-ACCEPT-DELAY-MS ::= 5_000

/** Mutable LoRaWAN 1.0.x activation and frame-counter state. */
class Session:
  device-address/int
  network-session-key/ByteArray
  application-session-key/ByteArray
  uplink-counter/int := ?
  downlink-counter/int := ?

  constructor
      --.device-address/int
      --.network-session-key/ByteArray
      --.application-session-key/ByteArray
      --.uplink-counter/int=0
      --.downlink-counter/int=0:

/**
Blocking LoRaWAN 1.0.x Class A end device.

The class implements ABP uplinks and OTAA joins with RX1 and RX2 windows. The
  caller is responsible for persisting session keys and both frame counters.
*/
class ClassA:
  radio_/lora.Radio
  region_/region.Region
  session/Session? := null
  data-rate/int
  tx-power/int
  rx1-offset/int := ?
  rx2-data-rate/int? := ?
  receive-delay-ms/int := ?
  receive-window-ms/int

  constructor
      --radio/lora.Radio
      --region/region.Region
      --.session/Session?=null
      --.data-rate/int=0
      --.tx-power/int=14
      --.rx1-offset/int=0
      --.rx2-data-rate/int?=null
      --.receive-delay-ms/int=1_000
      --.receive-window-ms/int=1_000:
    radio_ = radio
    region_ = region

  /**
  Sends one Class A uplink and returns a valid downlink received in RX1 or RX2.
  */
  send -> frames.Downlink?
      payload/io.Data
      --port/int=1
      --confirmed/bool=false
      --adr/bool=false:
    if not session: throw "LORAWAN_NOT_ACTIVATED"
    bytes := ByteArray payload.byte-size
    payload.write-to-byte-array bytes --at=0 0 payload.byte-size
    counter := session.uplink-counter
    uplink := region_.uplink --frame-counter=counter --data-rate=data-rate
    if bytes.size > uplink.max-payload-size: throw "LORAWAN_PAYLOAD_TOO_LARGE"
    frame := frames.build-uplink bytes
        --network-session-key=session.network-session-key
        --application-session-key=session.application-session-key
        --device-address=session.device-address
        --frame-counter=counter
        --port=port
        --confirmed=confirmed
        --adr=adr
    configure_ uplink
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
  join -> Session?
      --application-key/ByteArray
      --join-eui/ByteArray
      --device-eui/ByteArray
      --device-nonce/int:
    request := frames.build-join-request
        --application-key=application-key
        --join-eui=join-eui
        --device-eui=device-eui
        --device-nonce=device-nonce
    uplink := region_.uplink --frame-counter=device-nonce --data-rate=data-rate
    configure_ uplink
    radio_.transmit request
    transmitted-at := Time.monotonic-us
    response := receive-raw-windows_
        uplink
        transmitted-at
        JOIN-ACCEPT-DELAY-MS
    if not response: return null
    accepted := frames.parse-join-accept response
        --application-key=application-key
        --device-nonce=device-nonce
    rx1-offset = accepted.rx1-offset
    rx2-data-rate = accepted.rx2-data-rate
    receive-delay-ms = accepted.receive-delay-seconds * 1_000
    session = Session
        --device-address=accepted.device-address
        --network-session-key=accepted.network-session-key
        --application-session-key=accepted.application-session-key
    return session

  receive-data-windows_ -> frames.Downlink?
      uplink/region.RadioParameters
      transmitted-at/int:
    frame := receive-raw-windows_ uplink transmitted-at receive-delay-ms
    if not frame: return null
    counter := reconstruct-counter_ session.downlink-counter frame
    downlink := frames.parse-downlink frame
        --network-session-key=session.network-session-key
        --application-session-key=session.application-session-key
        --device-address=session.device-address
        --frame-counter=counter
    session.downlink-counter = counter + 1
    return downlink

  receive-raw-windows_ -> ByteArray?
      uplink/region.RadioParameters
      transmitted-at/int
      delay-ms/int:
    first := region_.rx1
        --uplink-channel=uplink.channel
        --data-rate=data-rate
        --offset=rx1-offset
    configure_ first --receive
    wait-until_ transmitted-at + delay-ms * 1_000
    frame := receive-window_
    if frame: return frame
    second := region_.rx2 --data-rate=rx2-data-rate
    configure_ second --receive
    wait-until_ transmitted-at + (delay-ms + 1_000) * 1_000
    return receive-window_

  configure_ -> none
      parameters/region.RadioParameters
      --receive/bool=false:
    configuration := lora.Configuration
        --frequency=parameters.frequency
        --bandwidth=parameters.bandwidth
        --spreading-factor=parameters.spreading-factor
        --coding-rate=5
        --preamble-length=8
        --crc=not receive
        --invert-iq=receive
        --sync-word=lora.PUBLIC-SYNC-WORD
        --tx-power=tx-power
    radio_.configure configuration

  receive-window_ -> ByteArray?:
    caller-deadline := Task.current.deadline
    window-deadline := Time.monotonic-us + receive-window-ms * 1_000
    packet/lora.Packet? := null
    timed-out := catch --unwind=(: it != DEADLINE-EXCEEDED-ERROR):
      with-timeout --ms=receive-window-ms: packet = radio_.receive
    if timed-out:
      if caller-deadline and caller-deadline <= window-deadline:
        rethrow timed-out.value timed-out.trace
      return null
    return packet.payload

  static reconstruct-counter_ -> int
      expected/int
      frame/ByteArray:
    if frame.size < 8: throw "LORAWAN_DOWNLINK_TOO_SHORT"
    low := frame[6] | (frame[7] << 8)
    candidate := (expected & 0xffff_0000) | low
    if candidate < expected: candidate += 0x1_0000
    return candidate

  static wait-until_ -> none
      deadline/int:
    remaining := deadline - Time.monotonic-us
    if remaining > 0: sleep (Duration --us=remaining)
