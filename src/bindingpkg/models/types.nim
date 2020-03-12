

# ================
# Type Definitions
# ================

type

  Action* {.pure.} = enum
    Setup
    Create
    Delete
    List
    Show
    Tag

  Command* = set[Action]
