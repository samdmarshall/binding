# =======
# Imports
# =======

import os
import tables
import parsecfg
import sequtils
import strutils
import parseopt2

import notmuch
import parsetoml 

# =====
# Types
# =====

type 
  TagSelection = enum
    None,
    All,
    New

type
  TaggingRule = object
    name: string
    rule: string

# =========
# Functions
# =========

proc progName(): string =
  result = getAppFilename().extractFilename()

proc usage(): void =
  echo("usage: " & progName() & " [-v|--version] [-h|--help] [--config:path]")
  quit(QuitSuccess)

proc versionInfo(): void =
  echo(progname() & " v0.1")
  quit(QuitSuccess)

template checkStatus(status: notmuch_status_t) =
  case status
  of NOTMUCH_STATUS_SUCCESS:
    discard
  else:
    echo("Error: " & $status.to_string())
    quit(QuitFailure)

proc composeFilterName(parent: string, child: string): string = 
  var composed_name = ""
  if len(parent) > 0:
    composed_name &= parent & "."
  composed_name &= child
  return composed_name

proc collectRules(filter: TomlTableRef, name: string): seq[TaggingRule] =
  var rules = newSeq[TaggingRule]()
  var child_filters = newSeq[string]()
  for key, value in filter.pairs():
    let filter_name = composeFilterName(name, key)
    case value.kind
    of TomlValueKind.Table:
      if len(name) > 0:
        child_filters.add(filter_name)
      let subfilter = value.tableVal
      let children = subfilter.collectRules(filter_name)
      rules = rules.concat(children)
    of TomlValueKind.String:
      let rule_string = value.stringVal.strip()
      if len(rule_string) > 0 and key == "rule":
        let new_rule = TaggingRule(name: name, rule: value.stringVal)
        rules.add(new_rule)
    else:
      discard
  if len(name) > 0:
    var tag_rules = newSeq[string]()
    for item in child_filters:
      let rule = "tag:" & item
      tag_rules.add(rule)
    if len(tag_rules) > 0:
      let rule_string = tag_rules.join(" or ")
      let parent_rule = TaggingRule(name: name, rule: rule_string)
      rules.add(parent_rule)
  return rules

# ===========
# Entry Point
# ===========

var selection: TagSelection = None
var configuration_path: string
if existsEnv("BINDING_CONFIG"):
  configuration_path = getEnv("BINDING_CONFIG").expandTilde()
else:
  configuration_path = expandTilde("~/.config/binding/config.toml")

for kind, key, value in getopt():
  case kind
  of cmdLongOption, cmdShortOption:
    case key
    of "help", "h":
      usage()
    of "version", "v":
      versionInfo()
    of "config":
      configuration_path = expandTilde(value)
    of "all":
      selection = All
    of "new":
      selection = New
    else:
      discard
  else:
    discard

if not configuration_path.fileExists():
  echo("unable to find a configuration file at '" & configuration_path & "'! Please;")
  echo("  1. create it")
  echo("  -- or --")
  echo("  2. specify the path to the configuration file using:")
  echo("    * the command line flag `--config:path`")
  echo("    -- or --")
  echo("    * the environment variable `BINDING_CONFIG`")
  quit(QuitFailure)

if selection == None:
  echo("No filter selection specified, please pass either `--all` or `--new`!")
  quit(QuitFailure)

if not existsEnv("NOTMUCH_CONFIG"):
  echo("Unable to locate the notmuch configuration file, please define `NOTMUCH_CONFIG` in your environment")
  quit(QuitFailure)

let configuration_full_path = configuration_path.expandFilename()
let filter = parseFile(configuration_full_path)
let rules = filter.collectRules("")

let notmuch_config_path = expandTilde(getEnv("NOTMUCH_CONFIG")).expandFilename()
let notmuch_config = loadConfig(notmuch_config_path)
let notmuch_database_path = notmuch_config.getSectionValue("database", "path")

var database: notmuch_database_t
let open_status = open(notmuch_database_path, NOTMUCH_DATABASE_MODE_READ_WRITE, addr database)
checkStatus(open_status)

case selection
of All:
  discard
of New:
  discard
else:
  discard



let close_status = database.close()
checkStatus(close_status)

let destroy_status = database.destroy()
checkStatus(destroy_status)
