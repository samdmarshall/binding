
# =======
# Imports
# =======

import re

#import bindingpkg/logger
import "../logger.nim"
#import bindingpkg/models / [types]
import "../models/types.nim"

# =========
# Functions
# =========


#
#
proc performShow*(config: Configuration, showRuleNamed: string) =

  for rule in config.rules:
    var matched: array[1, string]
    if match(rule.name, re(showRuleNamed), matched):
      echo rule.name
      echo rule.reqs
