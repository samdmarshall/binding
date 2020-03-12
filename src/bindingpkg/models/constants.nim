
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

  CommandSetup* = "setup"
  CommandCreate* = "create"
  CommandDelete* = "delete"
  CommandList* = "list"
  CommandShow* = "show"
  CommandTag* = "tag"
  CommandUsage* = "usage"
  Commands* = [CommandSetup, CommandCreate, CommandDelete, CommandList,
      CommandShow, CommandTag, CommandUsage]

  Configuration_Directory* = getConfigDir() / ApplicationName
  Configuration_File* = Configuration_Directory / "config.toml"

  Logging_Directory* = Configuration_Directory / "logs"
  Logging_File* = Logging_Directory / "messages.log"

