
# =======
# Imports
# =======

import os

import logger
import models / [ constants ]

import notmuch

# =========
# Templates
# =========

#
#
template checkStatus*(status: notmuch_status_t) =
  case status
  of NOTMUCH_STATUS_SUCCESS:
    discard
  else:
    error($status.status_to_string())

# =========
# Functions
# =========

#
#
proc expandPathRelativeToConfiguration*(path: string): string =
  var path_value_tilde_expand = path.expandTilde()
  var path_value_normalized = path_value_tilde_expand.normalizedPath()
  let (dir, file) = path_value_normalized.splitPath()
  if len(dir) == 0:
    result = Configuration_Directory / file
  else:
    result = path_value_normalized.expandFilename()
