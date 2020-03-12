
# =======
# Imports
# =======

import parsecfg
import strformat

import parsetoml

#import "../logger.nim"

# =====
# Types
# =====

type
  CommandWord* = enum
    Noop,
    Version,
    Usage,
    List,
    Tag

  TagSelection* {.pure.} = enum
    None,
    All,
    New

  Instruction* = object
    cmd: CommandWord
    sub: CommandWord

  RuleCombiner* = enum
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
    case kind*: RuleCombiner
    of None:
      value*: string
    else:
      values*: seq[string]

  TaggingRule* = object
    name*: string
    reqs*: seq[Requirement]

  Inventory* = object
    path*: string
    data*: TomlValueRef
    notmuch_config*: Config
    rules*: seq[TaggingRule]
    selection*: TagSelection


# =========
# Functions
# =========


# ===========
# Instruction
# ===========

#
#
proc set*(instr: var Instruction, command: CommandWord) =
  #[
    1. (Noop, Noop) - Valid
    2. (Noop, Some) - Invalid
    3. (Some, Noop) - Valid
    4. (Some, Some) - Valid
  ]#
  case instr.cmd
  of Noop:
    case instr.sub
    of Noop:
      # 1
      instr.cmd = command
    else:
      # 2
      discard
  else:
    case instr.sub
    of Noop:
      # 3
      instr.sub = instr.cmd
      instr.cmd = command
    else:
      # 4
      discard

#
#
proc getCommand*(instr: Instruction): CommandWord =
  result = instr.cmd

#
#
proc getSubcommand*(instr: Instruction): CommandWord =
  result = instr.sub

#
#
proc `$`*(instr: Instruction): string =
  result = fmt"Instruction(cmd: {instr.getCommand}, sub: {instr.getSubcommand})"


# =========
# Inventory
# =========

#
#
proc newInventory*(path: string): Inventory =
  result.path = path
  result.data = nil

# ===========
# TaggingRule
# ===========

#
#
proc `@`*(rc: RuleCombiner): string =
  case rc
  of TagAND, TagOR:
    "tag"
  of DateAND, DateOR:
    "date"
  of FromAND, FromOR:
    "from"
  of ToAND, ToOR:
    "to"
  of CcAND, CcOR:
    "cc"
  of SubjectAND, SubjectOR:
    "subject"
  else:
    "[INVALID]"

#
#
proc joinerWord*(rc: RuleCombiner): string =
  case rc
  of TagAND, DateAND, FromAND, ToAND, CcAND, SubjectAND:
    " and "
  of TagOR, DateOR, FromOR, ToOR, CcOR, SubjectOR:
    " or "
  else:
    " and "

#
#
proc `@`(req: Requirement): string =
  case req.kind
  of Invalid:
    discard
  of None:
    result = fmt"({req.kind}:{req.value})"
  else:
    for item in req.values:
      let individual = fmt"({req.kind}:{item})"
      if len(result) > 0:
        result &= fmt"{req.kind.joinerWord}"
      result &= fmt"{individual}"

#
#
proc `@`*(rule: TaggingRule): string =
  var requirements = ""
  for requirement in rule.reqs.items():
    case requirement.kind
    of RuleCombiner.Invalid:
      discard
    of RuleCombiner.None:
      if len(requirements) > 0:
        requirements &= requirement.kind.joinerWord()
      requirements &= @requirement
    else:
      discard
      for req in requirement.values:
        let individual = fmt"({@req})"
        if len(requirements) > 0:
          requirements &= fmt"{requirement.kind.joinerWord}"
        requirements &= fmt"({individual})"

  result = fmt"Rule: {rule.name} ==> {requirements}"

#
#
proc composeFilterName*(section: string, rule: string): string =
  if len(rule) > 0:
    result = fmt"{section}.{rule}"
  else:
    result = fmt"{section}"

#
#
proc createRule*(section: string, name: string = "", properties: TomlValueRef): TaggingRule =
  result.name = composeFilterName(section, name)
  result.reqs = newSeq[Requirement]()

  echo result.name
  case properties.kind
  of TomlValueKind.Table:
    for key, value in properties.tableVal.pairs():
      echo fmt"key: {key}"
  of TomlValueKind.Array:
    for item in properties.arrayVal.items():
      echo fmt"item: {item}"
  of TomlValueKind.String:
    echo fmt"string: {properties.stringVal}"
  else:
    discard

#
#
proc parseRulesFromFile*(file: string): seq[TaggingRule] =
  result = newSeq[TaggingRule]()
  let rules_data = parseFile(file).tableVal

  for section, value in rules_data.pairs():
    let rule = value.tableVal
    if len(rule) > 1:
      for name, properties in rule.pairs():
        let child_rule = createRule(section, name, properties)
        result.add(child_rule)
    let section_rule = createRule(section, properties = value)
    result.add(section_rule)

#[
#
#
proc collectRules*(filter: TomlTableRef, name: string): seq[TaggingRule] =
  result = newSeq[TaggingRule]()
  var child_filters = newSeq[string]()
  for key, value in filter.pairs():
    let filter_name = composeFilterName(name, key)
    debug("creating rule '" & filter_name & "'...")
    case value.kind
    of TomlValueKind.Table:
      if len(name) > 0:
        child_filters.add filter_name
      let subfilter = value.tableVal
      let children = subfilter.collectRules(filter_name)
      result = result.concat(children)
    of TomlValueKind.Array:
      debug("  array value:")
      var conditions = newSeq[string]()
      let combiner =
        try: parseEnum[RuleCombiner](key)
        except: Invalid
      for item in value.arrayVal:
        if item.kind == TomlValueKind.String:
          if combiner != Invalid:
            let rule_string = @combiner & ":" & item.stringVal
            conditions.add rule_string
      if len(conditions) > 0:
        let rule_string = conditions.join(combiner.joinerWord())
        let new_rule = TaggingRule(name: name, rule: rule_string)
        debug("    built rule: " & rule_string)
        result.add new_rule
    of TomlValueKind.String:
      debug("  string value:")
      let rule_string = value.stringVal.strip()
      if len(rule_string) > 0 and key == "rule":
        let new_rule = TaggingRule(name: name, rule: value.stringVal)
        debug("    built rule: " & $value.stringVal)
        result.add new_rule
    else:
      discard
  if len(name) > 0:
    var tag_rules = newSeq[string]()
    for item in child_filters:
      let rule = "tag:" & item
      tag_rules.add rule
    if len(tag_rules) > 0:
      let rule_string = tag_rules.join(" or ")
      let parent_rule = TaggingRule(name: name, rule: rule_string)
      result.add parent_rule
]#
