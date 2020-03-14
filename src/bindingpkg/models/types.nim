

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

  Definition* = enum
    Invalid = "[INVALID]",
    None = "rule",
    TagOR = "tag-or",
    TagAND = "tag-and",
    DateOR = "date-or",
    DateAND = "date-and",
    FromOR = "from-or",
    FromAND = "from-and",
    ToOR = "to-or",
    ToAND = "to-and",
    CcOR = "cc-or",
    CcAND = "cc-and",
    SubjectOR = "subject-or",
    SubjectAND = "subject-and"

  Requirement* = object
    case kind*: Definition
    of None:
      value*: string
    else:
      values*: seq[string]

  TaggingRule* = object
    name*: string
    reqs*: seq[Requirement]

  Configuration* = object
    bindingPath*: string
    notmuchPath*: string
    rulesPath*: string
    rules*: seq[TaggingRule]
