
# =======
# Imports
# =======

import strutils
import terminal

import "../logger.nim"
import "../models/types.nim"

# =========
# Functions
# =========

#
#
proc list*(inv: Inventory) =
  for item in inv.rules:
    let message = @item
    info(message)

    var display = message
    display = display.replace(" or ", " $1or$2 " % [ansiStyleCode(
          styleBright), ansiResetCode])
    display = display.replace(" and ", " $1and$2 " % [ansiStyleCode(
          styleBright), ansiResetCode])
    display = display.replace(" not ", " $1not$2 " % [ansiStyleCode(
          styleBright), ansiResetCode])
    display = display.replace("tag:", "$1tag:$2" % [ansiForegroundColorCode(
          fgRed, true), ansiResetCode])
    display = display.replace("date:", "$1date:$2" % [ansiForegroundColorCode(
          fgGreen, true), ansiResetCode])
    display = display.replace("from:", "$1from:$2" % [ansiForegroundColorCode(
          fgYellow, true), ansiResetCode])
    display = display.replace("to:", "$1to:$2" % [ansiForegroundColorCode(
          fgBlue, true), ansiResetCode])
    display = display.replace("cc:", "$1cc:$2" % [ansiForegroundColorCode(
          fgMagenta, true), ansiResetCode])
    display = display.replace("subject:", "$1subject:$2" % [
        ansiForegroundColorCode(fgCyan, true), ansiResetCode])

    var name = "$#$#$#$#" % [ansiStyleCode(styleBright), ansiStyleCode(
        styleUnderscore), item.name, ansiResetCode]
    echo name, ":\n  ", display
