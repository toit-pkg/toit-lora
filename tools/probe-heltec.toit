// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import .probe

main:
  probe-sx126x --reset=12 --busy=13 --clock=9 --mosi=10 --miso=11 --cs=8
