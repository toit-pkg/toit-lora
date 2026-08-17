// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import .probe

main:
  probe-sx126x --reset=15 --busy=39 --clock=14 --mosi=47 --miso=21 --cs=48
