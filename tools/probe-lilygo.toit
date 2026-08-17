// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import .probe

main:
  probe-sx127x --reset=23 --clock=5 --mosi=27 --miso=19 --cs=18
