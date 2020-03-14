
# =======
# Imports
# =======

import strutils

import bindingpkg/logger
import bindingpkg/utils
import bindingpkg/models / [types, constants, configuration, rule]
import bindingpkg/actions / [setup, create, delete, list, show, tag]

import commandeer

# =========
# Functions
# =========

#
#
proc main() =
  # Define the command line interface
  commandline:
    exitoption "help", "h", "Usage: $1 $3 $4 $5 $6 [command]" % [ApplicationName, Commands.join("|"), cli(["v", "version"]), cli(["h", "help"]), cli(["verbose"]), cli(["c", "config"], "file")]
    exitoption "version", "v", "$1 v$2" % [ApplicationName, NimblePkgVersion]
    option isVerbose, bool, "verbose", "", false
    option sessionConfigurationPath, string, "config", "c", Configuration_File
    subcommand isCommandSetup, CommandSetup:
      exitoption "help", "h", "Usage: $1 $2" % [ApplicationName, CommandSetup]
    subcommand isCommandCreate, CommandCreate:
      exitoption "help", "h", "Usage: $1 $2 <name>" % [ApplicationName, CommandCreate]
      argument createRuleNamed, string
    subcommand isCommandDelete, CommandDelete:
      exitoption "help", "h", "Usage: $1 $2 <name>" % [ApplicationName, CommandDelete]
      argument deleteRuleNamed, string
    subcommand isCommandList, CommandList:
      exitoption "help", "h", "Usage: $1 $2 <pattern>" % [ApplicationName, CommandList]
      argument namePattern, string
    subcommand isCommandShow, CommandShow:
      exitoption "help", "h", "Usage: $1 $2 <name>" % [ApplicationName, CommandShow]
      argument showRuleNamed, string
    subcommand isCommandTag, CommandTag:
      exitoption "help", "h", "Usage: $1 $2 $3 $4" % [ApplicationName, CommandTag, cli(["all"]), cli(["new"])]
      option tagAll, bool, "all", "", false
      option tagNew, bool, "new", "", false

  # ================================== #

  initiateLogger()

  enableVerboseLogging(isVerbose)

  let performingSetup = (isCommandSetup and (not (isCommandCreate or isCommandDelete or isCommandList or isCommandShow or isCommandTag)))
  let noCommandGiven = (not (isCommandSetup or isCommandCreate or isCommandDelete or isCommandList or isCommandShow or isCommandTag))
  let shouldBypassNormalStartup = (performingSetup or noCommandGiven)

  var configuration: Configuration

  if shouldBypassNormalStartup:
    if performingSetup:
      notice("Bypassing normal startup process, reason: setup command specified.")
    if noCommandGiven:
      notice("Bypassing normal startup process, reason: no command specified.")
  else:
    configuration = parseConfiguration(sessionConfigurationPath)

  # Perform Subcommand Action
  if isCommandSetup:
    performSetup()
  if isCommandCreate:
    performCreate(configuration, createRuleNamed)
  if isCommandDelete:
    performDelete(configuration, deleteRuleNamed)
  if isCommandList:
    performList(configuration, namePattern)
  if isCommandShow:
    performShow(configuration, showRuleNamed)
  if isCommandTag:
    performTag(configuration, tagAll, tagNew)

# ==========
# Main Entry
# ==========

when isMainModule:
  main()
