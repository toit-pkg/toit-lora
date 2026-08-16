// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import system.services

UUID ::= "d582ab8b-fc4b-49cf-a7b2-fb0cd6bea666"

SELECTOR-v1 ::= services.ServiceSelector
    --uuid=UUID
    --major=1
    --minor=0

TRANSMIT-INDEX-v1 ::= 0
RECEIVE-INDEX-v1  ::= 1
STANDBY-INDEX-v1  ::= 2
SLEEP-INDEX-v1    ::= 3
