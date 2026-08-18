// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the examples/LICENSE file.

function decodeUplink(input) {
  if (input.bytes.length !== 2) {
    return {errors: ["Expected a two-byte temperature payload"]};
  }
  let centiDegrees = (input.bytes[0] << 8) | input.bytes[1];
  if (centiDegrees & 0x8000) centiDegrees -= 0x10000;
  return {data: {temperature_c: centiDegrees / 100}};
}
