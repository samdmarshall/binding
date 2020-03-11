
# =======
# Imports
# =======

import os
import strformat

# ======
# Static
# ======

const
  ApplicationName* = "binding"

  MajorVersion* = 0
  MinorVersion* = 3
  PatchVersion* = 0
  ApplicationVersion* = fmt"{MajorVersion}.{MinorVersion}.{PatchVersion}"

  Configuration_Directory* = getConfigDir() / ApplicationName
  Configuration_File* = Configuration_Directory / "config.toml"

  Logging_Directory* = Configuration_Directory / "logs"
  Logging_File* = Logging_Directory / "messages.log"

  Command_List* = "list"
  Command_Tag* = "tag"
  Command_Version* = "version"
  Command_Help* = "help"
  Command_Usage* = "usage"

  Flag_Long_Verbose* = "verbose"
  Flag_Long_Version* = "version"
  Flag_Short_Version* = "v"
  Flag_Long_Config* = "config"
  Flag_Short_Config* = "c"
  Flag_Long_All* = "all"
  Flag_Short_All* = "a"
  Flag_Long_New* = "new"
  Flag_Short_New* = "n"
  Flag_Long_Usage* = "usage"
  Flag_Short_Usage* = "?"
  Flag_Long_Help* = "help"
  Flag_Short_Help* = "h"
