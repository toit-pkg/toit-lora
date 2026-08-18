// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the examples/LICENSE file.

import lora.radio-service

/**
Sends one LoRa packet through an installed LoRa radio service provider.
*/
main:
  radio := radio-service.v1
  try:
    radio.transmit "hello-from-service-client"
    print "LORA_SERVICE_TX_DONE"
    packet := radio.receive --timeout-ms=5_000
    if packet:
      print "LORA_SERVICE_RX $(packet.payload.to-string) RSSI=$(packet.rssi) SNR=$(packet.snr)"
    else:
      print "LORA_SERVICE_RX_TIMEOUT"
  finally:
    radio.close
