# LoRa for Toit

Clean LoRa packet-radio drivers for Semtech SX126x and SX127x transceivers.
The two chip families implement the same blocking `Radio` API while retaining
their different command/register transports internally.

## Supported hardware

| Board | MCU | Radio | SPI | Control |
| --- | --- | --- | --- | --- |
| Heltec WiFi LoRa 32 V3 | ESP32-S3 | SX1262 | SCK 9, MOSI 10, MISO 11, CS 8 | RESET 12, BUSY 13, DIO1 14, DIO2 RF switch, 1.8 V DIO3 TCXO |
| LILYGO T3 LoRa32 V1.6 | ESP32 | SX1276 | SCK 5, MOSI 27, MISO 19, CS 18 | RESET 23, DIO0 26 |

Both boards were probed from Toit and exchanged packets in both directions at
868.1 MHz. The examples retain these exact tested pin maps.

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

Applications in other containers can use the same `Radio` API through the
versioned `lora.radio-service` service. The first client that operates the
radio owns it until that client closes; competing clients receive
`LORA_RADIO_BUSY` instead of racing the modem configuration.

Install the provider for one of the tested boards:

```sh
jag container install lora-radio service/radio.toit \
    --device DEVICE \
    -D board=heltec
```

Then run a client in another container:

```sh
jag run examples/radio-service-client.toit --device DEVICE
```

Direct use remains available and does not import `system.services`.

## Packages

- The root package contains the plain LoRa drivers and raw service API.
- `service/radio.toit` is the configurable provider container for the tested
  boards.

## Verification

```sh
make test
```
