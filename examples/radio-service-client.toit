// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the examples/LICENSE file.

import lora
import lora.radio-service

main:
  radio := radio-service.v1
  try:
    radio.configure (lora.Configuration --frequency=868_100_000)
    radio.transmit "hello-from-service-client".to-byte-array
    print "LORA_SERVICE_TX_DONE"
  finally:
    radio.close
