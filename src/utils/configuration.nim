import os, tables, strutils, parsecfg

proc replaceValue(value: var string, replacementValues: Table[string, string]): string =
  #iterates over the replacemet table to see if we can replace something
  var presentVars: seq[string] = @[]
  for key in replacementValues.keys():
    if value.find(key) != -1:
      presentVars.add(key.replace("$",""))
      presentVars.add(replacementValues[key])
  value = value % presentVars
  return value
      
proc generateReplacmentTable(dict: Config): Table[string, string] =
  #iterates over the configuration table to replace all
  #replaceable values with the real values
  var replacementTable = initTable[string, string]()
  #itereate over the sections
  for sectionKey in dict.keys():
    #extract section
    var section = dict[sectionKey]
    #iterate over items in that section
    for itemKey in section.keys():
      #extract the value of this item
      var value = section[itemKey]
      #if the key contains `$` it is a replacement item
      if itemKey.find("$") != -1:
        #if the value contains `$` should be replaced with something
        var count = 0
        while value.find("$") != -1 or count < len(replacementTable):
          value = replaceValue(value, replacementTable)
          count += 1
        replacementTable.add(itemKey, value)
  return replacementTable

proc readConfiguration*(): Config =
  #currently reads from test directory
  var baseDir = os.getCurrentDir() & "/../src"
  var dict = loadConfig(baseDir & "/packagemanager.cfg")
  var replacementTable = generateReplacmentTable(dict) 
  for sectionKey in dict.keys():
    var section = dict[sectionKey]
    for itemKey in section.keys():
      var value = section[itemKey]
      #if the value contains `$` should be replaced with something
      var count = 0
      while value.find("$") != -1 or count < len(replacementTable):
        value = replaceValue(value, replacementTable)
        count += 1
      dict.setSectionKey(sectionKey, itemKey, value)
  return dict
