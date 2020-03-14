# Package

version       = "0.2.2"
author        = "Samantha Marshall"
description   = "simple tagging system for notmuch mail"
license       = "BSD 3-Clause"

srcDir        = "src/"
binDir        = "build/"
bin           = @["binding"]

# Dependencies

requires "nim >= 1.0.0"

requires "parsetoml >= 0.5.0"
requires "notmuch >= 5.2.0"
