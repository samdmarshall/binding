# =======
# Imports
# =======

import os
import logging
import strutils

import models / [constants]

# =========
# Constants
# =========

const
  VerboseFormat = "[$datetime] - [$levelname]: "

# =========
# Templates
# =========

template notice*(fmtString: string) =
  let pos = instantiationInfo()
  let message = "[$1:$2] $3" % [pos.filename, $pos.line, fmtString]
  notice(message)

template info*(fmtString: string) =
  let pos = instantiationInfo()
  let message = "[$1:$2] $3" % [pos.filename, $pos.line, fmtString]
  info(message)

template debug*(fmtString: string) =
  let pos = instantiationInfo()
  let message = "[$1:$2] $3" % [pos.filename, $pos.line, fmtString]
  debug(message)

template warn*(fmtString: string) =
  let pos = instantiationInfo()
  let message = "[$1:$2] $3" % [pos.filename, $pos.line, fmtString]
  warn(message)

template error*(fmtString: string) =
  let pos = instantiationInfo()
  let message = "[$1:$2] $3" % [pos.filename, $pos.line, fmtString]
  error(message)

template fatal*(fmtString: string) =
  let pos = instantiationInfo()
  let message = "[$1:$2] $3" % [pos.filename, $pos.line, fmtString]
  fatal(message)
  quit(QuitFailure)

# =========
# Functions
# =========

#
#
proc initiateLogger*() =
  if existsOrCreateDir(Logging_Directory):
    let app_logger = newRollingFileLogger(Logging_File, fmtStr = VerboseFormat)
    addHandler(app_logger)

#
#
proc enableVerboseLogging*(status: bool = false) =
  let level =
    if status == true: lvlAll
    else: lvlWarn
  let verbose_logger = newConsoleLogger(level, VerboseFormat)
  addHandler(verbose_logger)

