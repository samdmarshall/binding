
# =======
# Imports
# =======

import os
import strformat

# ======
# Static
# ======

const

  NimblePkgVersion* {.strdefine.} = ""

  ApplicationName* = "binding"

  # === CLI Subcommand Names ===

  CommandSetup* = "setup"
  CommandCreate* = "create"
  CommandDelete* = "delete"
  CommandList* = "list"
  CommandShow* = "show"
  CommandTag* = "tag"
  CommandUsage* = "usage"
  Commands* = [CommandSetup, CommandCreate, CommandDelete, CommandList,
      CommandShow, CommandTag, CommandUsage]


  # === Configuration Location Paths ===

  Configuration_Directory* = getConfigDir() / ApplicationName
  Configuration_File* = Configuration_Directory / "config.toml"

  Logging_Directory* = Configuration_Directory / "logs"
  Logging_File* = Logging_Directory / "messages.log"


  # === Configuration File Keys ===

  ConfigSectionBinding* = "binding"
  ConfigSectionBindingKeyRules* = "rules"

  ConfigSectionBindingMark* = "binding.mark"
  ConfigSectionBindingMarkKeyUnread* = "unread"
  ConfigSectionBindingMarkKeyInbox* = "inbox"

  ConfigSectionNotmuch* = "notmuch"
  ConfigSectionNotmuchKeyConfig* = "config"

  ConfigSectionNotmuchDatabase* = "notmuch.database"
  ConfigSectionNotmuchDatabaseKeyPath* = "path"

  ConfigSectionNotmuchNew* = "notmuch.new"
  ConfigSectionNotmuchNewKeyTags* = "tags"

