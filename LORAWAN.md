# LoRaWAN for Toit

LoRaWAN 1.0.x end-device building blocks in the `lora` package.

Implemented:

- AES-CMAC and MIC generation
- FRMPayload encryption/decryption
- OTAA join-request and join-accept processing
- LoRaWAN 1.0.x session-key derivation
- confirmed and unconfirmed uplink encoding
- authenticated downlink decoding
- 32-bit frame counters
- EU868 and US915 channel/data-rate plans
- blocking Class A OTAA and ABP RX1/RX2 flow

The Class A end device uses the package's board-independent `lora.Radio`
interface and works with either SX126x or SX127x drivers.

## End-device service

`lora.lorawan.end-device` exposes the Class A device through a versioned service.
The provider owns the physical radio, OTAA credentials, DevNonce, session keys,
and frame counters. It serializes calls from all client containers, so an
application only needs to join and send:

```toit
import lora.lorawan.end-device

main:
  device := end-device.v1
  try:
    if not device.activated and not device.join: return
    device.send "hello" --port=1
  finally:
    device.close
```

The service API's `v1` is independent of the implemented LoRaWAN protocol
revision, which is currently 1.0.x.

In this combined driver repository, `service/lorawan.toit` is a concrete,
board-independent provider container. Supply the radio family and wiring; for
example, for a Heltec WiFi LoRa 32 V3:

```sh
jag container install lorawan service/lorawan.toit \
    --device DEVICE \
    -D radio=sx1262 \
    -D spi-clock=9 -D spi-mosi=10 -D spi-miso=11 -D spi-cs=8 \
    -D reset=12 -D busy=13 -D dio1=14 \
    -D dio2-rf-switch=true -D tcxo-voltage=1800 \
    -D region=eu868 \
    -D app-key=APP_KEY \
    -D join-eui=JOIN_EUI \
    -D device-eui=DEVICE_EUI

jag run examples/lorawan-service-client.toit --device DEVICE
```

The provider remains installed indefinitely. It opens and configures the radio
on the first client operation, shares it between connected clients, and closes
the hardware after the last client disconnects.

For production deployment, attach the credentials as protected container
configuration rather than placing secrets in shell history. The provider uses
a device-specific `toit.io/lorawan/<device-eui>` flash bucket by default. It
reserves each DevNonce before transmitting the Join-Request, saves a joined
session before exposing it, and persists each uplink counter before radio
transmission. An authenticated downlink counter is committed before the
downlink is returned to a client.

The OTAA example reads `app-key`, `join-eui`, `device-eui`, and `device-nonce`
from Jaguar defines. No device identity or root key is compiled into the
package. Although an all-zero JoinEUI can be valid for a particular network
registration, it is not a universal LoRaWAN default and must be supplied
explicitly.

For LoRaWAN 1.0.4, DevNonce is a persistent 16-bit counter. Increment and
persist it *before* every Join-Request; reusing a value with the same JoinEUI
causes a compliant Join Server to reject the request. Direct users remain
responsible for this state; the service provider handles it automatically.

Direct applications must persist frame counters and session keys before
production use. Duty-cycle scheduling, ADR command processing, channel-mask
MAC commands, multicast, Class B/C, LoRaWAN 1.1, and certification are not yet
implemented. The EU868/US915 defaults are suitable for initial interoperability
work, not a substitute for regional compliance and LoRa Alliance certification
testing.

## MoleNet sensor example

`examples/molenet-bme280.toit` reads the MoleNet v7.1 onboard BME280 over I2C
and sends temperature on application port 1 through the LoRaWAN service. Its
two-byte payload is a signed, big-endian count of hundredths of a degree
Celsius. Paste `examples/molenet-bme280-decoder.js` into The Things Stack's
uplink payload formatter to expose the value as `temperature_c`.

Run the host-side protocol and receive-window tests with:

```
make test
```
