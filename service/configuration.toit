// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a BSD0-style license that can be
// found in the LICENSE file.

import encoding.tison
import system.assets

/** Loads service configuration from container assets. */
load -> Map:
  decoded := assets.decode
  ["configuration", "artemis.defines", "jag.defines"].do: | key/string |
    bytes := decoded.get key
    if not bytes: continue.do
    configuration := tison.decode bytes
    if configuration is not Map: throw "LORA_INVALID_CONFIGURATION"
    return configuration
  throw "LORA_MISSING_CONFIGURATION"

/** Returns the required string stored under $key. */
required-string configuration/Map key/string -> string:
  value := configuration.get key
  if value is not string: throw "LORA_MISSING_CONFIGURATION_$key"
  return value

/** Returns the integer under $key, or $fallback when it is absent. */
optional-int configuration/Map key/string fallback/int -> int:
  value := configuration.get key
  if not value: return fallback
  if value is int: return value
  if value is string: return int.parse value
  throw "LORA_INVALID_CONFIGURATION_$key"

/** Returns the string under $key, or $fallback when it is absent. */
optional-string configuration/Map key/string fallback/string -> string:
  value := configuration.get key
  if not value: return fallback
  if value is not string: throw "LORA_INVALID_CONFIGURATION_$key"
  return value
