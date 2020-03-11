# =======
# Imports
# =======

import os
import tables
import parsecfg
import parseopt
import sequtils
import strutils
#import db_sqlite
import strformat
import parseutils

import notmuch
import parsetoml

import utils
import logger
import models / [ constants, types ]
import commands / [ list, tag, usage, version ]


# =========
# Functions
# =========

#
#
proc main() =
  initiateLogger()

  var inv = newInventory(Configuration_File)
  var command = Instruction()
  inv.selection = TagSelection.None
  var verbose_logging = false

  var parser = initOptParser()
  for kind, key, value in parser.getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of Flag_Long_Usage, Flag_Short_Usage:
        command.set(Usage)
      of Flag_Long_Help, Flag_Short_Help:
        command.set(Usage)
      of Flag_Long_Version, Flag_Short_Version:
        command.set(Version)
      of Flag_Long_Config, Flag_Short_Config:
        inv.path = value
      of Flag_Long_All, Flag_Short_All:
        if command.getCommand() == Tag:
          inv.selection = All
      of Flag_Long_New, Flag_Short_New:
        if command.getCommand() == Tag:
          inv.selection = New
      of Flag_Long_Verbose:
        verbose_logging = true
      else:
        discard
    of cmdArgument:
      case key
      of Command_List:
        command.set(List)
      of Command_Tag:
        command.set(Tag)
      of Command_Version:
        command.set(Version)
      of Command_Usage, Command_Help:
        command.set(Usage)
      else:
        discard
    else:
      discard

  enableVerboseLogging(verbose_logging)

  if not existsDir(Configuration_Directory):
    fatal("")

  if not existsFile(Configuration_File):
    fatal("")

  if not existsDir(Configuration_Directory):
    let xdg_config_directory = getConfigDir()
    if not existsDir(xdg_config_directory):
      notice("The environment variable `XDG_CONFIG_HOME` is not defined and the default value `~/.config/` doesn't exist on the filesystem. ")
      error("Unable to find a configuration file!")

  if not existsFile(Configuration_File):
    fatal("unable to find a configuration file at '" & Configuration_File & "'!")

  if command.getCommand() == Tag and inv.selection == TagSelection.None:
    fatal("No filter selection specified, please pass either `--all` or `--new`!")

  inv.data = parseFile(inv.path)

  if not inv.data.hasKey("notmuch"):
    fatal("binding's configuration file must specify an section for the details about your notmuch setup!")

  let notmuch_key_value = inv.data["notmuch"].tableVal
  if not notmuch_key_value.hasKey("config"):
    fatal("binding's configuration file must specify an entry for the notmuch config!")

  let notmuch_config_path_value = notmuch_key_value["config"].stringVal
  let notmuch_config_path = expandPathRelativeToConfiguration(notmuch_config_path_value)
  inv.notmuch_config = loadConfig(notmuch_config_path)


  var notmuch_database_path: string

  if not notmuch_key_value.hasKey("database"):
    notmuch_database_path = inv.notmuch_config.getSectionValue("database", "path")
  else:
    notmuch_database_path = notmuch_key_value["database"]["path"].stringVal

  var new_mail_tags: seq[string]

  if not notmuch_key_value.hasKey("new"):
    new_mail_tags = inv.notmuch_config.getSectionValue("new", "tags").split(';')
  else:
    let raw_tags = notmuch_key_value["new"]["tags"].arrayVal
    for tag in raw_tags:
      new_mail_tags.add(tag.stringVal)

  if len(new_mail_tags) == 0:
    error("In order for 'binding' to work, your notmuch config must specify at least one tag to be applied to 'new' mail; or set overrides to this value in 'binding's config.toml under the section [notmuch.new] using the key 'tags' (takes an array of strings)")
    quit(QuitFailure)

  if not inv.data.hasKey("binding"):
    let binding_key_value = inv.data["binding"].tableVal
    if not binding_key_value.hasKey("rules"):
      fatal("binding's configuration file must specify an entry to the rules file!")

  let rules_path_value = inv.data["binding"]["rules"].stringVal
  let rules_path = expandPathRelativeToConfiguration(rules_path_value)
  inv.rules = parseRulesFromFile(rules_path)

  let mark_tags_value = inv.data["binding"]["mark"].tableVal
  var mark_tags = newTable[string, seq[string]]()
  for mark_tag, match_tags in pairs(mark_tags_value):
    var match_tag_seq = newSeq[string]()
    for entry in match_tags.arrayVal:
      match_tag_seq.add(entry.stringVal)
    mark_tags[mark_tag] = match_tag_seq


  case command.getCommand()
  of List:
    list(inv)
  of Tag:
    tag(inv)
  of Version:
    version()
  of Usage:
    usage(command.getSubcommand())
  else:
    usage()


# ===========
# Entry Point
# ===========

when isMainModule:
  main()
