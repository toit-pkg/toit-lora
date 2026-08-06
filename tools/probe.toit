// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import gpio
import spi

main args:
  if args.size != 2: throw "Usage: probe <sx126x|sx127x> <reset-pin>"
  family := args[0]
  reset-number := int.parse args[1]
  if family == "sx126x":
    probe-sx126x reset-number
  else if family == "sx127x":
    probe-sx127x reset-number
  else:
    throw "Unknown radio family: $family"

probe-sx126x reset-number/int:
  reset := gpio.Pin reset-number
  reset.configure --output --value=1
  sleep --ms=10
  reset.set 0
  sleep --ms=2
  reset.set 1
  sleep --ms=20

  busy := gpio.Pin 13
  busy.configure --input
  print "SX126x BUSY=$(busy.get)"

  bus := spi.Bus --clock=9 --mosi=10 --miso=11
  device := bus.device --cs=8 --frequency=1_000_000
  status := #[0xc0, 0x00]
  device.transfer status --read
  print "SX126x status=$status"
  sync-word := #[0x1d, 0x07, 0x40, 0x00, 0x00, 0x00]
  device.transfer sync-word --read
  print "SX126x sync-word=$sync-word"

  device.close
  bus.close
  busy.close
  reset.close

probe-sx127x reset-number/int:
  reset := gpio.Pin reset-number
  reset.configure --output --value=1
  sleep --ms=10
  reset.set 0
  sleep --ms=2
  reset.set 1
  sleep --ms=20

  bus := spi.Bus --clock=5 --mosi=27 --miso=19
  device := bus.device --cs=18 --frequency=1_000_000
  version := #[0x42, 0x00]
  device.transfer version --read
  print "SX127x reset=$reset-number version=$version"

  device.close
  bus.close
  reset.close
