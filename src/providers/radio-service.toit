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

/** Provides exclusive service access to one LoRa radio. */
class RadioServiceProvider extends services.ServiceProvider
    implements services.ServiceHandler:
  radio_/lora.Radio
  mutex_/monitor.Mutex ::= monitor.Mutex
  owner_/int? := null

  constructor .radio_ --name/string=NAME:
    super name --major=MAJOR --minor=MINOR
    provides api.SELECTOR-v1 --handler=this

  handle index/int arguments/any --gid/int --client/int -> any:
    return mutex_.do:
      claim_ client
      if index == api.CONFIGURE-INDEX-v1:
        continue.do radio_.configure (decode-configuration_ arguments)
      if index == api.TRANSMIT-INDEX-v1:
        continue.do radio_.transmit arguments
      if index == api.RECEIVE-INDEX-v1:
        packet := radio_.receive --timeout-ms=arguments
        continue.do packet ? [packet.payload, packet.rssi, packet.snr] : null
      if index == api.STANDBY-INDEX-v1:
        continue.do radio_.standby
      if index == api.SLEEP-RADIO-INDEX-v1:
        continue.do radio_.sleep-radio
      unreachable

  on-closed client/int -> none:
    mutex_.do:
      if owner_ != client: continue.do
      owner_ = null
      catch --trace: radio_.standby

  claim_ client/int -> none:
    if owner_ and owner_ != client: throw "LORA_RADIO_BUSY"
    owner_ = client

  static decode-configuration_ encoded/List -> lora.Configuration:
    if encoded.size != 9: throw "LORA_INVALID_SERVICE_CONFIGURATION"
    return lora.Configuration
        --frequency=encoded[0]
        --bandwidth=encoded[1]
        --spreading-factor=encoded[2]
        --coding-rate=encoded[3]
        --preamble-length=encoded[4]
        --crc=encoded[5]
        --invert-iq=encoded[6]
        --sync-word=encoded[7]
        --tx-power=encoded[8]

/** Installs a service provider for $radio. */
install radio/lora.Radio --name/string=NAME -> RadioServiceProvider:
  provider := RadioServiceProvider radio --name=name
  provider.install
  return provider
