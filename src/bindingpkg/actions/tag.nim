
# =======
# Imports
# =======

import notmuch

#import bindingpkg/logger
import "../logger.nim"
#import bindingpkg/models / [types]
import "../models/types.nim"

# =========
# Functions
# =========

#
#
proc performTag*(config: Configuration, tagAll: bool, tagNew: bool) =
  let tagOnlyNewMail = (not tagAll)
  let undefinedTaggingBehavior = (not tagAll) and (not tagNew)

  if undefinedTaggingBehavior:
    fatal("Please provide either `--all` or `--new` when using the `tag` subcommand.")

  if tagNew:
    notice("Detected `--new` flag; only newly fetched mail will be processed and tagged.")

  if tagAll:
    notice("Detected `--all` flag; all mail will be processed and tagged.")
