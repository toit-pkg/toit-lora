// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import monitor
import system.services

import ..apis.radio-service as api
import ..radio as lora

NAME ::= "toit.io/lora-radio"
MAJOR ::= 1
MINOR ::= 0

/** Provides serialized service access to one configured LoRa radio. */
class RadioServiceProvider extends services.ServiceProvider
    implements services.ServiceHandler:
  open_/Lambda
  radio_/lora.Radio? := null
  clients_/int := 0
  mutex_/monitor.Mutex ::= monitor.Mutex

  constructor --open/Lambda --name/string=NAME:
    open_ = open
    super name --major=MAJOR --minor=MINOR
    provides api.SELECTOR-v1 --handler=this

  on-opened client/int -> none:
    mutex_.do: clients_++

  on-closed client/int -> none:
    mutex_.do:
      clients_--
      if clients_ == 0: close-radio_

  handle index/int arguments/any --gid/int --client/int -> any:
    return mutex_.do:
      radio := ensure-radio_
      if index == api.TRANSMIT-INDEX-v1:
        continue.do radio.transmit arguments
      if index == api.RECEIVE-INDEX-v1:
        packet := receive_ radio arguments
        continue.do packet ? [packet.payload, packet.rssi, packet.snr] : null
      if index == api.STANDBY-INDEX-v1:
        continue.do radio.standby
      if index == api.SLEEP-INDEX-v1:
        continue.do radio.sleep
      unreachable

  receive_ radio/lora.Radio timeout-ms/int? -> lora.Packet?:
    if not timeout-ms: return radio.receive
    packet/lora.Packet? := null
    timed-out := catch --unwind=(: it != DEADLINE-EXCEEDED-ERROR):
      with-timeout --ms=timeout-ms: packet = radio.receive
    return timed-out ? null : packet

  ensure-radio_ -> lora.Radio:
    if radio_: return radio_
    opened/lora.Radio := open_.call
    radio_ = opened
    return opened

  close-radio_ -> none:
    radio := radio_
    radio_ = null
    if radio: radio.close

/**
Installs a service provider that obtains a configured radio from $open.

Calls $open on the first client operation and closes that radio after the last
  client disconnects.
*/
install --open/Lambda --name/string=NAME -> RadioServiceProvider:
  provider := RadioServiceProvider --open=open --name=name
  provider.install
  return provider
