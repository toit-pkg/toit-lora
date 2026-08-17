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
        --reset=(int.parse args[1])
        --busy=(int.parse args[2])
        --clock=(int.parse args[3])
        --mosi=(int.parse args[4])
        --miso=(int.parse args[5])
        --cs=(int.parse args[6])
  else if family == "sx127x":
    if args.size != 6: usage_
    probe-sx127x
        --reset=(int.parse args[1])
        --clock=(int.parse args[2])
        --mosi=(int.parse args[3])
        --miso=(int.parse args[4])
        --cs=(int.parse args[5])
  else:
    usage_

probe-sx126x
    --reset/int
    --busy/int
    --clock/int
    --mosi/int
    --miso/int
    --cs/int:
  reset-pin := gpio.Pin reset
  reset-pin.configure --output --value=1
  sleep --ms=10
  reset-pin.set 0
  sleep --ms=2
  reset-pin.set 1
  sleep --ms=20

  busy-pin := gpio.Pin busy
  busy-pin.configure --input
  print "SX126x BUSY=$(busy-pin.get)"

  bus := spi.Bus
      --clock=clock
      --mosi=mosi
      --miso=miso
  device := bus.device --cs=cs --frequency=1_000_000
  status := #[0xc0, 0x00]
  device.transfer status --read
  print "SX126x status=$status"
  sync-word := #[0x1d, 0x07, 0x40, 0x00, 0x00, 0x00]
  device.transfer sync-word --read
  print "SX126x sync-word=$sync-word"

  device.close
  bus.close
  busy-pin.close
  reset-pin.close

probe-sx127x
    --reset/int
    --clock/int
    --mosi/int
    --miso/int
    --cs/int:
  reset-pin := gpio.Pin reset
  reset-pin.configure --output --value=1
  sleep --ms=10
  reset-pin.set 0
  sleep --ms=2
  reset-pin.set 1
  sleep --ms=20

  bus := spi.Bus
      --clock=clock
      --mosi=mosi
      --miso=miso
  device := bus.device --cs=cs --frequency=1_000_000
  version := #[0x42, 0x00]
  device.transfer version --read
  print "SX127x reset=$reset version=$version"

  device.close
  bus.close
  reset-pin.close

usage_ -> none:
  throw "Usage: probe sx126x <reset> <busy> <clock> <mosi> <miso> <cs> | sx127x <reset> <clock> <mosi> <miso> <cs>"
