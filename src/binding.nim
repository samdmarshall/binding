# =======
# Imports
# =======

import os
import tables
import logging
import parsecfg
import parseopt
import sequtils
import strutils

import notmuch
import parsetoml

# ======
# Static
# ======

const configuration_path = getConfigDir() / "binding" / "config.toml"

# =====
# Types
# =====

type
  TagSelection = enum
    None,
    All,
    New,
    Debug

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
  return getAppFilename().extractFilename()

proc usage(): void =
  echo("usage: " & progName() & " [-v|--version] [-h|--help] [--new|--all]")
  quit(QuitSuccess)

proc versionInfo(): void =
  echo(progname() & " v0.2.0")
  quit(QuitSuccess)

proc parsePathFromConfigValue(path: string): string =
  var finalized_path = ""

  var path_value_tilde_expand = path.expandTilde()
  var path_value_normalized = path_value_tilde_expand.normalizedPath()
  let (dir, file) = path_value_normalized.splitPath()
  if len(dir) == 0:
    let config_dir = parentDir(configuration_path)
    finalized_path = config_dir / file
  else:
    finalized_path = path_value_normalized.expandFilename()

  return finalized_path

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
    debug("creating rule '" & filter_name & "'...") 
    case value.kind
    of TomlValueKind.Table:
      if len(name) > 0:
        child_filters.add(filter_name)
      let subfilter = value.tableVal
      let children = subfilter.collectRules(filter_name)
      rules = rules.concat(children)
    of TomlValueKind.Array:
      debug("  array value:")
      var conditions = newSeq[string]()
      for item in value.arrayVal:
        if item.kind == TomlValueKind.String:
          let rule_string = convertConditionalKey(key) & ":" & item.stringVal
          conditions.add(rule_string)
      if len(conditions) > 0 and knownConditionalKeys.contains(key):
        let rule_string = conditions.join(convertConditionalOperator(key))
        let new_rule = TaggingRule(name: name, rule: rule_string)
        debug("    built rule: " & rule_string)
        rules.add(new_rule)
    of TomlValueKind.String:
      debug("  string value:")
      let rule_string = value.stringVal.strip()
      if len(rule_string) > 0 and key == "rule":
        let new_rule = TaggingRule(name: name, rule: value.stringVal)
        debug("    built rule: " & $value.stringVal)
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

var logger: ConsoleLogger = newConsoleLogger(lvlError)

var selection: TagSelection = None

var parser = initOptParser()

for kind, key, value in parser.getopt():
  case kind
  of cmdLongOption, cmdShortOption:
    case key
    of "help", "h":
      usage()
    of "version", "v":
      versionInfo()
    of "all":
      selection = All
    of "new":
      selection = New
    of "verbose":
      logger = newConsoleLogger(lvlAll)
    of "debug":
      selection = Debug
    else:
      discard
  else:
    discard

addHandler(logger)

if not configuration_path.fileExists():
  fatal("unable to find a configuration file at '" & configuration_path & "'!")
  quit(QuitFailure)

if selection == None:
  fatal("No filter selection specified, please pass either `--all` or `--new`!")
  quit(QuitFailure)

let configuration = parseFile(configuration_path).tableVal

if not configuration.hasKey("notmuch"):
  error("binding's configuration file must specify an section for the details about your notmuch setup!")
  quit(QuitFailure)

let notmuch_key_value = configuration["notmuch"].tableVal
if not notmuch_key_value.hasKey("config"):
  error("binding's configuration file must specify an entry for the notmuch config!")
  quit(QuitFailure)

let notmuch_config_path_value = configuration["notmuch"]["config"].stringVal
let notmuch_config_path = parsePathFromConfigValue(notmuch_config_path_value)
let notmuch_config = loadConfig(notmuch_config_path)

let notmuch_configuration_overrides = configuration["notmuch"].tableVal

var database: notmuch_database_t
var notmuch_database_path: string

if not notmuch_configuration_overrides.hasKey("database"):
  notmuch_database_path = notmuch_config.getSectionValue("database", "path")
else:
  notmuch_database_path = notmuch_configuration_overrides["database"]["path"].stringVal

let open_status = open(notmuch_database_path, NOTMUCH_DATABASE_MODE_READ_WRITE, addr database)
checkStatus(open_status)

var new_mail_tags: seq[string]

if not notmuch_configuration_overrides.hasKey("new"):
  new_mail_tags = notmuch_config.getSectionValue("new", "tags").split(';')
else:
  let raw_tags = notmuch_configuration_overrides["new"]["tags"].arrayVal
  for tag in raw_tags:
    new_mail_tags.add(tag.stringVal)

if len(new_mail_tags) == 0:
  error("In order for 'binding' to work, your notmuch config must specify at least one tag to be applied to 'new' mail; or set overrides to this value in 'binding's config.toml under the section [notmuch.new] using the key 'tags' (takes an array of strings)")
  quit(QuitFailure)

if not configuration.hasKey("binding"):
  let binding_key_value = configuration["binding"].tableVal
  if not binding_key_value.hasKey("rules"):
    error("binding's configuration file must specify an entry to the rules file!")
    quit(QuitFailure)

let rules_path_value = configuration["binding"]["rules"].stringVal
let rules_path = parsePathFromConfigValue(rules_path_value)
let filter = parseFile(rules_path).tableVal
let rules = filter.collectRules("")

let mark_tags_value = configuration["binding"]["mark"].tableVal
var mark_tags = newTable[string, seq[string]]()
for mark_tag, match_tags in pairs(mark_tags_value):
  var match_tag_seq = newSeq[string]()
  for entry in match_tags.arrayVal:
    match_tag_seq.add(entry.stringVal)
  mark_tags[mark_tag] = match_tag_seq

for item in rules:
  info(item.name & " => " & item.rule)
 
case selection
of All:
  debug("Applying rules against all mail...")
  for filter in rules:
    debug("finding mail matching rule: " & filter.name)
    let query_based_on_rule_text = database.create(filter.rule)
    var messages_matching_rule: notmuch_messages_t
    let messages_matching_rule_status = query_based_on_rule_text.search_messages_st(addr messages_matching_rule)
    checkStatus(messages_matching_rule_status)

    for message in messages_matching_rule.items():
      let identifier = message.get_message_id()
      debug("  matched mail record: " & $identifier)
      let tag_added_status = message.add_tag(filter.name)
      checkStatus(tag_added_status)
      for mark, match_rules in pairs(mark_tags):
        if match_rules.contains(filter.name):
          let remove_marked_tag_status = message.remove_tag(mark)
          checkStatus(remove_marked_tag_status)
of New:
  debug("Applying rules against 'new' mail...")
  new_mail_tags.applyIt("tag:" & it)
  let initial_query = new_mail_tags.join(" or ")
  debug("Finding mail matching: '" & initial_query & "'...")
  let query: notmuch_query_t = database.create(initial_query)

  var message_count: cuint
  let count_messages_status = query.count_messages_st(addr message_count)
  checkStatus(count_messages_status)
  debug("Found " & $message_count & " messages matching rule...")
  if message_count == 0:
    debug("There are no messages to process, so we can quit early :)")
    quit(QuitSuccess)

  var messages: notmuch_messages_t
  let query_status = query.search_messages_st(addr messages)
  checkStatus(query_status)

  for message in messages.items():
    let identifier = message.get_message_id()
    debug("filtering message with id: " & $identifier & " ...")
    for filter in rules:
      var message_matched_rule_count: cuint = 0
      let check_rule_query_string = filter.rule & " and " & "(" & initial_query & ")"
      let matched_message_query_string = "id:" & $identifier & " and " & "(" & check_rule_query_string & ")"
      let check_rule_query = database.create(matched_message_query_string)
      let check_rule_query_status = check_rule_query.count_messages_st(addr message_matched_rule_count)
      checkStatus(check_rule_query_status)

      case message_matched_rule_count:
        of 0:
          continue
        of 1:
          debug("  matched to rule: " & filter.name & "!")
          let tagged_message_status = message.add_tag(filter.name)
          checkStatus(tagged_message_status)

          let split_name = filter.name.split(".")
          var pos = split_name.high()
          dec(pos)
          let low = split_name.low()
          while pos >= low:
            let parent_rule_name = split_name[low..pos].join(".")
            debug("  matched to parent rule: " & parent_rule_name & "!")
            let parent_rule_tagged_message_status = message.add_tag(parent_rule_name)
            checkStatus(parent_rule_tagged_message_status)
            dec(pos)

          for mark, match_rules in pairs(mark_tags):
            if match_rules.contains(filter.name):
              debug("  removing tag name: " & mark & "!")
              let remove_marked_tag_status = message.remove_tag(mark)
              checkStatus(remove_marked_tag_status)
        else:
          fatal("Found more than one message with the same identifier, aborting!!")
          quit(QuitFailure)
  query.destroy()
else:
  discard

let close_status = database.close()
checkStatus(close_status)

let destroy_status = database.destroy()
checkStatus(destroy_status)
