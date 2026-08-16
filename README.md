# LoRa for Toit

Clean LoRa packet-radio driver for the Semtech SX126x family.

## Supported hardware

| Board | MCU | Radio | SPI | Control |
| --- | --- | --- | --- | --- |
| Heltec WiFi LoRa 32 V3 | ESP32-S3 | SX1262 | SCK 9, MOSI 10, MISO 11, CS 8 | RESET 12, BUSY 13, DIO1 14, DIO2 RF switch, 1.8 V DIO3 TCXO |

The board was probed from Toit and exchanged packets at 868.1 MHz. The
examples retain the exact tested pin map.

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

See `examples/heltec-ping.toit` for complete resource cleanup and a
bidirectional test.

## Verification

```sh
make test
```
