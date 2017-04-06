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
import progress
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
# Constants
# =========

const 
  TagOR = "tag-or"
  TagAND = "tag-and"
  DateOR = "date-or"
  DateAND = "date-and"
  FromOR = "from-or"
  FromAND = "from-and"
  ToOR = "to-or"
  ToAND = "to-and"
  CcOR = "cc-or"
  CcAND = "cc-and"
  SubjectOR = "subject-or"
  SubjectAND = "subject-and"
  
  knownConditionalKeys = @[
    TagOR,
    TagAND,
    DateOR,
    DateAND,
    FromOR,
    FromAND,
    ToOR,
    ToAND,
    CcOR,
    CcAND,
    SubjectOR,
    SubjectAND 
  ]


# =========
# Templates
# =========

template checkStatus(status: notmuch_status_t) =
  case status
  of NOTMUCH_STATUS_SUCCESS:
    discard
  else:
    echo("Error: " & $status.to_string())
    quit(QuitFailure)

template convertConditionalKey(key: string): string =
  case key:
  of TagOR, TagAND:
    "tag"
  of DateOR, DateAND:
    "date"
  of FromOR, FromAND:
    "from"
  of ToOR, ToAND:
    "to"
  of CcOR, CcAND:
    "cc"
  of SubjectOR, SubjectAND:
    "subject"
  else:
    ""

template convertConditionalOperator(key: string): string =
  case key:
  of TagOR, DateOR, FromOR, ToOR, CcOR, SubjectOR:
    " or "
  of TagAND, DateAND, FromAND, ToAND, CcAND, SubjectAND:
    " and "
  else:
    ""

# =========
# Functions
# =========

proc progName(): string =
  result = getAppFilename().extractFilename()

proc usage(): void =
  echo("usage: " & progName() & " [-v|--version] [-h|--help] [--new|--all] (--config:path) (--is-tty)")
  quit(QuitSuccess)

proc versionInfo(): void =
  echo(progname() & " v0.1")
  quit(QuitSuccess)

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
    of TomlValueKind.Array:
      var conditions = newSeq[string]()
      for item in value.arrayVal:
        if item.kind == TomlValueKind.String:
          let rule_string = convertConditionalKey(key) & ":" & item.stringVal
          conditions.add(rule_string)
      if len(conditions) > 0 and knownConditionalKeys.contains(key):
        let rule_string = conditions.join(convertConditionalOperator(key))
        let new_rule = TaggingRule(name: name, rule: rule_string)
        rules.add(new_rule)
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

var enable_tty = false
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
    of "is-tty":
      enable_tty = true
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

var initial_query = ""
case selection
of All:
  initial_query = "*"
of New:
  initial_query = "tag:new"
else:
  discard

let query: notmuch_query_t = database.create(initial_query)

var message_count: cuint
let count_messages_status = query.count_messages_st(addr message_count)
checkStatus(count_messages_status)

if message_count == 0:
  # there are no messages to process, so we can quit early :)
  quit(QuitSuccess)

var bar: ProgressBar
# start the progress bar if it is a tty
if enable_tty:
  let signed_message_count = int64(message_count)
  let signed_int_message_count = int(signed_message_count)
  bar = newProgressBar(signed_int_message_count)
  bar.start()

var messages: notmuch_messages_t
let query_status = query.search_messages_st(addr messages)
checkStatus(query_status)

for message in messages.items():
  var did_filter_from_inbox = false
  let identifier = message.get_message_id()

  for filter in rules:
    # TODO: replace this with a faster search implementation, this is eating a lot of processing time
    var matched_messages: notmuch_messages_t
    let check_rule_query_string = "id:" & $identifier & " and " & filter.rule
    let check_rule_query = database.create(check_rule_query_string)
    let check_rule_query_status = check_rule_query.search_messages_st(addr matched_messages)
    checkStatus(check_rule_query_status)
    for matched_message in matched_messages.items():
      let add_tag_status = matched_message.add_tag(filter.name)
      checkStatus(add_tag_status)
      did_filter_from_inbox = true
      
  let tags = message.get_tags()
  for tag_name in tags.items():
    case $tag_name
    of "new":
      let remove_new_tag_status = message.remove_tag(tag_name)
      checkStatus(remove_new_tag_status)
    else:
      discard
    if did_filter_from_inbox:
      let remove_inbox_tag_status = message.remove_tag("inbox")
      checkStatus(remove_inbox_tag_status)

  if enable_tty:
    bar.increment()

query.destroy()

if enable_tty:
  bar.finish()
  echo("\n")

let close_status = database.close()
checkStatus(close_status)

let destroy_status = database.destroy()
checkStatus(destroy_status)
