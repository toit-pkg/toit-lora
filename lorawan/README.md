# LoRaWAN for Toit

Standalone LoRaWAN 1.0.x end-device building blocks, prepared as a separate
Toit package.

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

The package deliberately exposes a tiny `device.Radio` interface. This keeps
it independent of any radio chip; `examples/adapter.toit` shows how to bridge
the SX126x/SX127x package.

The OTAA example reads `app-key`, `join-eui`, `device-eui`, and `device-nonce`
from Jaguar defines. No device identity or root key is compiled into the
package. Although an all-zero JoinEUI can be valid for a particular network
registration, it is not a universal LoRaWAN default and must be supplied
explicitly.

For LoRaWAN 1.0.4, DevNonce is a persistent 16-bit counter. Increment and
persist it *before* every Join-Request; reusing a value with the same JoinEUI
causes a compliant Join Server to reject the request. The example accepts the
counter as a define so that it does not pretend to provide durable storage.

Applications must persist frame counters and session keys before production
use. Duty-cycle scheduling, ADR command processing, channel-mask MAC commands,
multicast, Class B/C, LoRaWAN 1.1, and certification are not yet implemented.
The EU868/US915 defaults are suitable for initial interoperability work, not a
substitute for regional compliance and LoRa Alliance certification testing.

Run the host-side protocol and receive-window tests with:

```
make test
```
