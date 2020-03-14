
# =======
# Imports
# =======

import re
import strutils

#import bindingpkg/logger
import "../logger.nim"
#import bindingpkg/models / [types]
import "../models/types.nim"

# =========
# Functions
# =========


#
#
proc performlist*(config: Configuration, namePattern: string) =

  for rule in config.rules:
    var matched: array[1, string]
    if match(rule.name, re(namePattern), matched):
      echo rule.name
