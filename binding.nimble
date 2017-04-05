# Package

version       = "0.1.0"
author        = "Samantha Marshall"
description   = "simple tagging system for notmuch mail"
license       = "BSD 3-Clause"
srcDir        = "src"

bin = @["binding"]

# Dependencies

requires "nim >= 0.16.0"
requires "parsetoml >= 0.2"
requires "notmuch >= 0.1.0"

