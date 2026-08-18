// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import system.services

UUID ::= "e7ebbb43-d7de-4650-8c77-b45a4aa64340"

SELECTOR-v1 ::= services.ServiceSelector
    --uuid=UUID
    --major=1
    --minor=0

ACTIVATED-INDEX-v1 ::= 0
JOIN-INDEX-v1      ::= 1
SEND-INDEX-v1      ::= 2
