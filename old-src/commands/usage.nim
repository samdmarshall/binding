
# =======
# Imports
# =======

import terminal

import strutils
import strformat

import "../models/constants.nim"
import "../models/types.nim"

# =========
# Functions
# =========

#
#
proc usage*(cmd: CommandWord = Noop) =
  var message = ""
  let starter = "usage: $#" % [ApplicationName]
  case cmd
  of Noop:
    message &= fmt"{starter} [list|tag|version|usage|help] [[-?|--usage]|[-h|--help]] [-v|--version] [--verbose] [-c <file>|--config=<file>]"
  of List:
    message &= fmt"{starter} list [--verbose]"
  of Tag:
    message &= fmt"{starter} tag [[-n|--new]|[-a|--all]] [--verbose]"
  of Version:
    message &= fmt"{starter} [version]"
    message &= &"\n"
    message &= fmt"{starter} [-v|--version]"
  of Usage:
    message &= fmt"{starter} [usage|help] [[-?|--usage]|[-h|--help]] [--verbose]"
    message &= &"\n"
    message &= &"\n"
    message &= fmt"{starter} [usage|help] list"
    message &= &"\n"
    message &= fmt"{starter} list [[-?|--usage]|[-h|--help]]"
    message &= &"\n"
    message &= &"\n"
    message &= fmt"{starter} [usage|help] tag"
    message &= &"\n"
    message &= fmt"{starter} tag [[-?|--usage]|[-h|--help]]"
    message &= &"\n"
    message &= &"\n"
    message &= fmt"{starter} [usage|help] version"
    message &= &"\n"
    message &= fmt"{starter} version [[-?|--usage]|[-h|--help]]"
    message &= &"\n"
  echo message
