
# =======
# Imports
# =======

import strformat

import "../models/constants.nim"

# =========
# Functions
# =========

#
#
proc version*() =
  echo fmt"{ApplicationName} v{ApplicationVersion}\nBuilt with Nim: {NimVersion} on {CompileDate} @ {CompileTime}\n"

