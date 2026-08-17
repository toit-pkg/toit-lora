// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import monitor
import system.services

import ..apis.end-device as api
import ..device as device
import ..frames as frames

NAME ::= "toit.io/lorawan-end-device"
MAJOR ::= 1
MINOR ::= 0

/** OTAA root credentials held by an end-device provider. */
class OtaaCredentials:
  application-key/ByteArray
  join-eui/ByteArray
  device-eui/ByteArray

  constructor
      --.application-key/ByteArray
      --.join-eui/ByteArray
      --.device-eui/ByteArray:
    if application-key.size != 16: throw "LORAWAN_INVALID_APPLICATION_KEY"
    if join-eui.size != 8 or device-eui.size != 8:
      throw "LORAWAN_INVALID_EUI"

/** Persistent state boundary required by an end-device provider. */
interface StateStore:
  /** Loads the most recently saved session, or returns null. */
  load-session -> device.Session?

  /**
  Reserves and persists a fresh DevNonce before returning it.

  Implementations must never return a previously returned value.
  */
  reserve-device-nonce -> int

  /**
  Saves $session, including both frame counters.

  Implementations must respect caller deadlines. The provider orders writes
    before radio operations and shields only an accepted downlink counter.
  */
  save-session -> none
      session/device.Session

/** Volatile state store intended for tests and short-lived experiments. */
class MemoryStateStore implements StateStore:
  session_/device.Session? := null
  next-device-nonce_/int := ?

  constructor --session/device.Session?=null --next-device-nonce/int=0:
    session_ = session and clone-session_ session
    next-device-nonce_ = next-device-nonce

  /** See $StateStore.load-session. */
  load-session -> device.Session?:
    return session_ and clone-session_ session_

  /** See $StateStore.reserve-device-nonce. */
  reserve-device-nonce -> int:
    if not 0 <= next-device-nonce_ <= 0xffff:
      throw "LORAWAN_DEVICE_NONCE_EXHAUSTED"
    reserved := next-device-nonce_
    next-device-nonce_++
    return reserved

  /** See $StateStore.save-session. */
  save-session -> none
      session/device.Session:
    session_ = clone-session_ session

  static clone-session_ -> device.Session
      session/device.Session:
    return device.Session
        --device-address=session.device-address
        --network-session-key=session.network-session-key
        --application-session-key=session.application-session-key
        --uplink-counter=session.uplink-counter
        --downlink-counter=session.downlink-counter

/** Provides serialized service access to one LoRaWAN Class A end device. */
class EndDeviceServiceProvider extends services.ServiceProvider
    implements services.ServiceHandler:
  open_/Lambda
  close_/Lambda
  end-device_/device.ClassA? := null
  state-store_/StateStore
  credentials_/OtaaCredentials?
  clients_/int := 0
  mutex_/monitor.Mutex ::= monitor.Mutex

  constructor
      --open/Lambda
      --close/Lambda
      --state-store/StateStore
      --credentials/OtaaCredentials?=null
      --name/string=NAME:
    open_ = open
    close_ = close
    state-store_ = state-store
    credentials_ = credentials
    super name --major=MAJOR --minor=MINOR
    provides api.SELECTOR-v1 --handler=this

  on-opened client/int -> none:
    mutex_.do: clients_++

  on-closed client/int -> none:
    mutex_.do:
      clients_--
      if clients_ == 0: close-end-device_

  handle -> any
      index/int
      arguments/any
      --gid/int
      --client/int:
    return mutex_.do:
      end-device := ensure-end-device_
      if index == api.ACTIVATED-INDEX-v1:
        continue.do end-device.session != null
      if index == api.JOIN-INDEX-v1:
        continue.do join_ end-device
      if index == api.SEND-INDEX-v1:
        continue.do send_ end-device arguments
      unreachable

  join_ end-device/device.ClassA -> bool:
    if end-device.session: return true
    credentials := credentials_
    if not credentials: throw "LORAWAN_OTAA_NOT_CONFIGURED"
    device-nonce := state-store_.reserve-device-nonce
    previous-rx1-offset := end-device.rx1-offset
    previous-rx2-data-rate := end-device.rx2-data-rate
    previous-receive-delay-ms := end-device.receive-delay-ms
    session := end-device.join
        --application-key=credentials.application-key
        --join-eui=credentials.join-eui
        --device-eui=credentials.device-eui
        --device-nonce=device-nonce
    if not session: return false
    saved := false
    try:
      state-store_.save-session session
      saved = true
    finally:
      if not saved:
        end-device.session = null
        end-device.rx1-offset = previous-rx1-offset
        end-device.rx2-data-rate = previous-rx2-data-rate
        end-device.receive-delay-ms = previous-receive-delay-ms
    return true

  send_ -> List?
      end-device/device.ClassA
      arguments/List:
    if arguments.size != 4: throw "LORAWAN_INVALID_SERVICE_ARGUMENTS"
    downlink := end-device.send arguments[0]
        --port=arguments[1]
        --confirmed=arguments[2]
        --adr=arguments[3]
        --on-counter-reserved=:
          state-store_.save-session end-device.session
    if not downlink: return null
    // A received downlink must be committed before it is exposed to the
    // client, otherwise a reset could allow the same frame to be processed
    // again.
    critical-do --no-respect-deadline:
      state-store_.save-session end-device.session
    return [
      downlink.confirmed,
      downlink.adr,
      downlink.acknowledgement,
      downlink.frame-pending,
      downlink.frame-counter,
      downlink.options,
      downlink.port,
      downlink.payload,
    ]

  ensure-end-device_ -> device.ClassA:
    if end-device_: return end-device_
    opened/device.ClassA := open_.call
    succeeded := false
    try:
      opened.session = state-store_.load-session
      end-device_ = opened
      succeeded = true
      return opened
    finally:
      if not succeeded: close_.call opened

  close-end-device_ -> none:
    end-device := end-device_
    end-device_ = null
    if end-device: close_.call end-device

/**
Installs a service provider that obtains a Class A end device from $open.

Calls $open on the first client operation and $close after the last client
  disconnects. The $state-store persists activation and frame-counter state
  across those hardware lifetimes.
*/
install -> EndDeviceServiceProvider
    --open/Lambda
    --close/Lambda
    --state-store/StateStore
    --credentials/OtaaCredentials?=null
    --name/string=NAME:
  provider := EndDeviceServiceProvider
      --open=open
      --close=close
      --state-store=state-store
      --credentials=credentials
      --name=name
  provider.install
  return provider
