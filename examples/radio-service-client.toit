// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the examples/LICENSE file.

import lora
import lora.radio-service

/**
Sends one LoRa packet through an installed LoRa radio service provider.

The provider owns the board-specific radio and pin configuration; this client
  only selects the common 868.1 MHz radio configuration.
*/
main:
  radio := radio-service.v1
  try:
    configuration := lora.Configuration
    radio.configure configuration
    radio.transmit "hello-from-service-client".to-byte-array
    print "LORA_SERVICE_TX_DONE"
  finally:
    radio.close
