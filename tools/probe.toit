// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import gpio
import spi

main args:
  if args.is-empty: usage_
  family := args[0]
  if family == "sx126x":
    if args.size != 7: usage_
    probe-sx126x
        (int.parse args[1])
        (int.parse args[2])
        (int.parse args[3])
        (int.parse args[4])
        (int.parse args[5])
        (int.parse args[6])
  else if family == "sx127x":
    if args.size != 6: usage_
    probe-sx127x
        (int.parse args[1])
        (int.parse args[2])
        (int.parse args[3])
        (int.parse args[4])
        (int.parse args[5])
  else:
    usage_

probe-sx126x
    reset-number/int
    busy-number/int
    clock-number/int
    mosi-number/int
    miso-number/int
    cs-number/int:
  reset := gpio.Pin reset-number
  reset.configure --output --value=1
  sleep --ms=10
  reset.set 0
  sleep --ms=2
  reset.set 1
  sleep --ms=20

  busy := gpio.Pin busy-number
  busy.configure --input
  print "SX126x BUSY=$(busy.get)"

  bus := spi.Bus
      --clock=clock-number
      --mosi=mosi-number
      --miso=miso-number
  device := bus.device --cs=cs-number --frequency=1_000_000
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

probe-sx127x
    reset-number/int
    clock-number/int
    mosi-number/int
    miso-number/int
    cs-number/int:
  reset := gpio.Pin reset-number
  reset.configure --output --value=1
  sleep --ms=10
  reset.set 0
  sleep --ms=2
  reset.set 1
  sleep --ms=20

  bus := spi.Bus
      --clock=clock-number
      --mosi=mosi-number
      --miso=miso-number
  device := bus.device --cs=cs-number --frequency=1_000_000
  version := #[0x42, 0x00]
  device.transfer version --read
  print "SX127x reset=$reset-number version=$version"

  device.close
  bus.close
  reset.close

usage_ -> none:
  throw "Usage: probe sx126x <reset> <busy> <clock> <mosi> <miso> <cs> | sx127x <reset> <clock> <mosi> <miso> <cs>"
