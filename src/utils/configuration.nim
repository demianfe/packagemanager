import os, tables, strutils, parsecfg

proc replaceValue(value: var string, replacementValues: OrderedTable[string, string]): string =
  #iterates over the replacemet table to see if we can replace something
  var presentVars: seq[string] = @[]
  for key in replacementValues.keys():
    #ignore case
    echo value.toLower()
    echo key.toLower()
    if value.toLower().find(key.toLower()) != -1:
      presentVars.add(key.replace("$",""))
      presentVars.add(replacementValues[key])
  value = value % presentVars
  return value
  
proc replaceValues*(config: Config, input:string ): string =
  #TODO: if variable is not found it should throw an error
  #iterates over the config table and replaces configuration values in the input string
  #count the number of `$` found in the input string
  var output: string = input
  try:
    var count = 0
    var presentVars: seq[string] = @[]
    var variablesCount = input.count("$")
    while count< variablesCount:
      for sectionKey in config.keys():
        var section = config[sectionKey]
        for key in section.keys():
          if input.find(key) != -1:
            presentVars.add(key.replace("$",""))
            presentVars.add(config[sectionKey][key])
      count += 1
    output = input % presentVars
  except:
    echo "No configuration found for line:"
    echo input
  return output
  #if the value contains `$` should be replaced with something
       
proc generateReplacmentTable(dict: Config): OrderedTable[string, string] =
  #iterates over the configuration table to replace all
  #replaceable values with the real values
  var replacementTable = initOrderedTable[string, string]()#initTable[string, string]()
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
  var baseDir = os.getCurrentDir() & "/src"
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
