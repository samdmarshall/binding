
# =======
# Imports
# =======

import parsecfg
import sequtils
import strutils

import notmuch
import parsetoml

import "../logger.nim"
import "../utils.nim"
import "../models/types.nim"

# =========
# Functions
# =========

#
#
proc tag*(inv: Inventory) =
  var database: notmuch_database_t

  let notmuch_configuration_overrides = inv.data["notmuch"].tableVal
  var notmuch_database_path: string

  if not notmuch_configuration_overrides.hasKey("database"):
    notmuch_database_path = inv.notmuch_config.getSectionValue("database", "path")
  else:
    notmuch_database_path = notmuch_configuration_overrides["database"]["path"].stringVal

  let open_status = open(notmuch_database_path, NOTMUCH_DATABASE_MODE_READ_WRITE, addr database)
  checkStatus(open_status)

  var new_mail_tags: seq[string]

  if not notmuch_configuration_overrides.hasKey("new"):
    new_mail_tags = inv.notmuch_config.getSectionValue("new", "tags").split(';')
  else:
    let raw_tags = notmuch_configuration_overrides["new"]["tags"].arrayVal
    for tag in raw_tags:
      new_mail_tags.add(tag.stringVal)

  if len(new_mail_tags) == 0:
    error("In order for 'binding' to work, your notmuch config must specify at least one tag to be applied to 'new' mail; or set overrides to this value in 'binding's config.toml under the section [notmuch.new] using the key 'tags' (takes an array of strings)")
    quit(QuitFailure)

  if not inv.data.hasKey("binding"):
    let binding_key_value = inv.data["binding"].tableVal
    if not binding_key_value.hasKey("rules"):
      fatal("binding's configuration file must specify an entry to the rules file!")

  let mark_tags_value = inv.data["binding"]["mark"].tableVal
  var mark_tags = newTable[string, seq[string]]()
  for mark_tag, match_tags in mark_tags_value.pairs():
    var match_tag_seq = newSeq[string]()
    for entry in match_tags.arrayVal:
      match_tag_seq.add(entry.stringVal)
    mark_tags[mark_tag] = match_tag_seq

  case inv.selection
  of All:
    debug("Applying rules against all mail...")
    for filter in inv.rules:
      debug("finding mail matching rule: " & filter.name)
      let query_based_on_rule_text = database.create(@filter)
      var messages_matching_rule: notmuch_messages_t
      let messages_matching_rule_status = query_based_on_rule_text.search_messages(addr messages_matching_rule)
      checkStatus(messages_matching_rule_status)

      for message in messages_matching_rule.items():
        let identifier = message.get_message_id()
        debug("  matched mail record: " & $identifier)
        let tag_added_status = message.add_tag(filter.name)
        checkStatus(tag_added_status)
        for (mark, match_rules) in mark_tags.pairs():
          if match_rules.contains(filter.name):
            let remove_marked_tag_status = message.remove_tag(mark)
            checkStatus(remove_marked_tag_status)
  of New:
    debug("Applying rules against 'new' mail...")
    new_mail_tags.applyIt("tag:" & it)
    let initial_query = new_mail_tags.join(" or ")
    debug("Finding mail matching: '" & initial_query & "'...")
    let query: notmuch_query_t = database.create(initial_query)

    var message_count: cuint
    let count_messages_status = query.count_messages(addr message_count)
    checkStatus(count_messages_status)
    debug("Found " & $message_count & " messages matching rule...")
    if message_count == 0:
      debug("There are no messages to process, so we can quit early :)")
      quit(QuitSuccess)

    var messages: notmuch_messages_t
    let query_status = query.search_messages(addr messages)
    checkStatus(query_status)

    for message in messages.items():
      let identifier = message.get_message_id()
      debug("filtering message with id: " & $identifier & " ...")
      for filter in inv.rules:
        var message_matched_rule_count: cuint = 0
        let check_rule_query_string = @filter & " and " & "(" &
            initial_query & ")"
        let matched_message_query_string = "id:" & $identifier & " and " & "(" &
            check_rule_query_string & ")"
        let check_rule_query = database.create(matched_message_query_string)
        let check_rule_query_status = check_rule_query.count_messages(addr message_matched_rule_count)
        checkStatus(check_rule_query_status)

        case message_matched_rule_count
        of 0:
          continue
        of 1:
          debug("  matched to rule: " & filter.name & "!")
          let tagged_message_status = message.add_tag(filter.name)
          checkStatus(tagged_message_status)

          let split_name = filter.name.split(".")
          var pos = split_name.high()
          dec(pos)
          let low = split_name.low()
          while pos >= low:
            let parent_rule_name = split_name[low..pos].join(".")
            debug("  matched to parent rule: " & parent_rule_name & "!")
            let parent_rule_tagged_message_status = message.add_tag(parent_rule_name)
            checkStatus(parent_rule_tagged_message_status)
            dec(pos)

          for mark, match_rules in mark_tags.pairs():
            if match_rules.contains(filter.name):
              debug("  removing tag name: " & mark & "!")
              let remove_marked_tag_status = message.remove_tag(mark)
              checkStatus(remove_marked_tag_status)
        else:
          fatal("Found more than one message with the same identifier, aborting!!")

    query.destroy()
  else:
    discard

    let close_status = database.close()
    checkStatus(close_status)

    let destroy_status = database.destroy()
    checkStatus(destroy_status)
