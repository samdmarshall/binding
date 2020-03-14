
# =======
# Imports
# =======

import os

import logger
import models / [constants]

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

