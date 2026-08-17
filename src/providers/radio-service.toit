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
  radio_/lora.Radio
  mutex_/monitor.Mutex ::= monitor.Mutex

  constructor .radio_ --name/string=NAME:
    super name --major=MAJOR --minor=MINOR
    provides api.SELECTOR-v1 --handler=this

  handle index/int arguments/any --gid/int --client/int -> any:
    return mutex_.do:
      if index == api.TRANSMIT-INDEX-v1:
        continue.do radio_.transmit arguments
      if index == api.RECEIVE-INDEX-v1:
        packet := receive_ arguments
        continue.do packet ? [packet.payload, packet.rssi, packet.snr] : null
      if index == api.STANDBY-INDEX-v1:
        continue.do radio_.standby
      if index == api.SLEEP-INDEX-v1:
        continue.do radio_.sleep
      unreachable

  receive_ timeout-ms/int? -> lora.Packet?:
    if not timeout-ms: return radio_.receive
    packet/lora.Packet? := null
    timed-out := catch --unwind=(: it != DEADLINE-EXCEEDED-ERROR):
      with-timeout --ms=timeout-ms: packet = radio_.receive
    return timed-out ? null : packet

/** Installs a service provider for the configured $radio. */
install radio/lora.Radio --name/string=NAME -> RadioServiceProvider:
  provider := RadioServiceProvider radio --name=name
  provider.install
  return provider
