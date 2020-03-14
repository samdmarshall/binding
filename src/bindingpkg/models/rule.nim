

# =======
# Imports
# =======

import os
import tables
import streams
import parsecfg
import strutils
import parseutils


#import bindingpkg/logger
import "../logger.nim"
#import bindingpkg/models / [types, constants, rule]
import "types.nim"
import "constants.nim"

# =========
# Functions
# =========

#
#
proc parseRule(): TaggingRule =
  result = TaggingRule()



#
#
proc parseRules*(path: string): seq[TaggingRule] =
  result = newSeq[TaggingRule]()

  if not existsFile(path):
    fatal("No rules file found at path '$#'" % [path])

  var fd = newFileStream(path, fmRead)
  var parser: CfgParser
  open(parser, fd, path)
  var isEoF = false
  var rule: TaggingRule
  while not isEoF:
    var entity = parser.next()
    case entity.kind
    of cfgEof:
      isEoF = true
    of cfgSectionStart:
      if len(rule.name) > 0:
        result.add(rule)
      rule = TaggingRule()
      rule.name = entity.section
    of cfgKeyValuePair:
      var filter = Requirement()
      try:
        filter.kind = parseEnum[Definition](entity.key, Invalid)
      except:
        discard
      case filter.kind
      of Invalid:
        discard
      of None:
        filter.value = entity.value
      else:
        filter.values = entity.value.split(",")
      rule.reqs.add(filter)
    of cfgOption:
      discard
    of cfgError:
      error(entity.msg)
      break

