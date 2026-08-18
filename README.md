# LoRa for Toit

Clean LoRa packet-radio drivers for Semtech SX126x and SX127x transceivers.
The two chip families implement the same blocking `Radio` API while retaining
their different command/register transports internally.

## Direct use

```toit
import spi
import lora
import lora.sx1262

main:
  bus := spi.Bus --clock=9 --mosi=10 --miso=11
  device := bus.device --cs=8 --frequency=4_000_000
  radio := sx1262.Sx1262 device 13
      --reset=12
      --dio1=14
      --tcxo-voltage=1_800
      --dio2-rf-switch
  configuration := lora.Configuration
  radio.configure configuration
  radio.transmit "hello"
```

See `examples/heltec-ping.toit` and `examples/lilygo-pong.toit` for complete
resource cleanup and a bidirectional test.

## Raw-radio service

Applications in other containers can transmit and receive through the
versioned `lora.radio-service` service. The service installation owns the LoRa
PHY configuration, and operations from multiple clients are serialized on the
shared modem. The provider remains installed indefinitely, opens the configured
radio on the first client operation, and closes it after the last client
disconnects.

Install the provider by supplying the radio family, wiring, and PHY settings.
For example, the Heltec wiring with the default 868.1 MHz configuration is:

```sh
jag container install lora-radio service/radio.toit \
    --device DEVICE \
    -D radio=sx1262 \
    -D spi-clock=9 -D spi-mosi=10 -D spi-miso=11 -D spi-cs=8 \
    -D reset=12 -D busy=13 -D dio1=14 \
    -D dio2-rf-switch=true -D tcxo-voltage=1800
```

Then run a client in another container:

```sh
jag run examples/radio-service-client.toit --device DEVICE
```

Direct use remains available and does not import `system.services`.

## Packages

- The package contains the plain LoRa drivers, raw service API, and LoRaWAN
  support under `lora.lorawan`.
- `service/` contains board-independent raw LoRa and LoRaWAN provider
  containers. Radio family, SPI wiring, control pins, RF-switch control, and
  TCXO voltage are supplied as configuration. The timing-sensitive LoRaWAN
  provider owns the plain radio directly rather than calling the raw-radio
  service. Both providers remain installed while opening radio hardware only
  for active clients. The LoRaWAN service stores state in the qualified flash
  bucket path `toit.io/lorawan/<device-eui>` by default.

## Verification

```sh
make test
```
