
# =======
# Imports
# =======

import os
import strutils

import parsetoml

#import bindingpkg/logger
import "../logger.nim"
#import bindingpkg/models / [types, constants, rule]
import "types.nim"
import "constants.nim"
import "rule.nim"

# =========
# Functions
# =========

#
#
proc expandPathRelativeToConfiguration(config, path: string): string =
  var path_value_tilde_expand = path.expandTilde()
  var path_value_normalized = path_value_tilde_expand.normalizedPath()
  let (dir, file) = path_value_normalized.splitPath()
  if len(dir) == 0:
    result = parentDir(config) / file
  else:
    result = path_value_normalized.expandFilename()

#
#
proc parseConfiguration*(path: string): Configuration =
  result = Configuration()

  if not existsFile(path):
    fatal("No configuration file exists at path: '$#'" % [path])

  result.bindingPath = path

  let config_data = parseFile(result.bindingPath).tableVal

  if not config_data.hasKey(ConfigSectionBinding):
    fatal("Configuration is missing section '$#'" % [ConfigSectionBinding])

  if not config_data.hasKey(ConfigSectionNotmuch):
    fatal("Configuration is missing section '$#'" % [ConfigSectionNotmuch])

  if not config_data[ConfigSectionBinding].hasKey(ConfigSectionBindingKeyRules):
    fatal("Configuration is missing key defining path to the rules file")

  let rules_path = expandPathRelativeToConfiguration(result.bindingPath,
      config_data[ConfigSectionBinding][ConfigSectionBindingKeyRules].stringVal)

  result.rules = parseRules(rules_path)

