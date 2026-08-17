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

  /** Saves $session, including both frame counters. */
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
  end-device_/device.ClassA
  state-store_/StateStore
  credentials_/OtaaCredentials?
  mutex_/monitor.Mutex ::= monitor.Mutex

  constructor
      --end-device/device.ClassA
      --state-store/StateStore
      --credentials/OtaaCredentials?=null
      --name/string=NAME:
    end-device_ = end-device
    state-store_ = state-store
    credentials_ = credentials
    end-device_.session = state-store_.load-session
    super name --major=MAJOR --minor=MINOR
    provides api.SELECTOR-v1 --handler=this

  handle -> any
      index/int
      arguments/any
      --gid/int
      --client/int:
    return mutex_.do:
      if index == api.ACTIVATED-INDEX-v1:
        continue.do end-device_.session != null
      if index == api.JOIN-INDEX-v1:
        continue.do join_
      if index == api.SEND-INDEX-v1:
        continue.do send_ arguments
      unreachable

  join_ -> bool:
    if end-device_.session: return true
    credentials := credentials_
    if not credentials: throw "LORAWAN_OTAA_NOT_CONFIGURED"
    device-nonce := state-store_.reserve-device-nonce
    session := end-device_.join
        --application-key=credentials.application-key
        --join-eui=credentials.join-eui
        --device-eui=credentials.device-eui
        --device-nonce=device-nonce
    if not session: return false
    state-store_.save-session session
    return true

  send_ -> List?
      arguments/List:
    if arguments.size != 4: throw "LORAWAN_INVALID_SERVICE_ARGUMENTS"
    downlink/frames.Downlink? := null
    try:
      downlink = end-device_.send arguments[0]
          --port=arguments[1]
          --confirmed=arguments[2]
          --adr=arguments[3]
          --on-counter-reserved=:
            state-store_.save-session end-device_.session
    finally:
      session := end-device_.session
      if session: state-store_.save-session session
    if not downlink: return null
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

/** Installs a service provider for $end-device using $state-store. */
install -> EndDeviceServiceProvider
    --end-device/device.ClassA
    --state-store/StateStore
    --credentials/OtaaCredentials?=null
    --name/string=NAME:
  provider := EndDeviceServiceProvider
      --end-device=end-device
      --state-store=state-store
      --credentials=credentials
      --name=name
  provider.install
  return provider
