
# =======
# Imports
# =======

import sequtils
import strutils

import notmuch

# =========
# Templates
# =========

#
#
template checkStatus*(status: notmuch_status_t) =
  case status
  of NOTMUCH_STATUS_SUCCESS:
    discard
  else:
    error(status_to_string(status))

# =========
# Functions
# =========

#
#
proc flagPrefix*(flag: string): string =
  let prefix =
    if len(flag) == 1: "-"
    else: "--"
  result = "$1$2" % [prefix, flag]

#
#
proc cli*(f: varargs[string, `$`], v: string = ""): string =
  result = "[$1]" % (f.mapIt(flagPrefix(it))).join("|")
  if len(v) > 0:
    result &= "=<$#>" % v
