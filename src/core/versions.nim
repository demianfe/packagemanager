# procs that help package version handling
# TODO: handle excluded versions
import tables, sequtils, algorithm, strutils, re
import ../utils/logger

type
  PreferredVersion* = tuple[version: string, path: string]

proc `$`*(preferredVersion: PreferredVersion): string =
  return preferredVersion.version & " : " & preferredVersion.path

proc strComparator(a: string, operator: string, b: string): SomeSignedInt =
  if operator == ">=":
    if a >= b:
      return 1
    else:
      return -1
  elif operator == ">" :
    if a > b:
      return 1
    else:
      return -1
  elif operator == "<=":
    if a <= b:
      return 1
    else:
      return -1
  elif operator == "<" :
    if a < b:
      return 1
    else:
      return -1
  elif operator == "=":
    if a == b:
     return 1
    else:
      return -1

proc intComparator(a: int, operator: string, b: int): SomeSignedInt =
  if operator == ">=":
    if a >= b:
      return 1
    else:
      return -1
  elif operator == ">" :
    if a > b:
      return 1
    else:
      return -1
  elif operator == "<=":
    if a <= b:
      return 1
    else:
      return -1
  elif operator == "<" :
    if a < b:
      return 1
    else:
      return -1
  elif operator == "=":
    if a == b:
     return 1
    else:
      return -1

proc comparator(a: string, operator: string, b: string): SomeSignedInt =
  # delegats to the specific comparator
  # basic logic:
  # if a and b ar ints use intComparator
  # if a is int and b is alpha, a wins
  # if a alpha and b is int, b wins
  # if a is alphaNumeric and the length of both 
  if isDigit(a) and isDigit(b):
    return intComparator(parseInt(a), operator, parseInt(b))
  else:
    return strComparator(a, operator, b)
    
#TODO: modify this procedure to recieve a index (int) and a string (version)
# compare character by character in the sequence:
#   if the character is a numeric call compareInt
#   else if the character is not numeric call compareChar (?)
# both this functions recieve the index of the it is representing and the character to be compared
# it then returns the index associated with the greatest character
proc compareVersions(v1: string, operator: string, v2: string): string =
  #compare a sequence of int values using intComparator      
  # let a = map(v1.split("."), proc(x: string): int = parseInt(x))
  # let b = map(v2.split("."), proc(x: string): int = parseInt(x))
  let a = v1.split(".")
  let b = v2.split(".")
  var i = 0
  var maxLength = len(a)
  
  if maxLength > len(b): maxLength = len(b)
  try:
    while i < maxLength:
      # echo "$1 $2 $3" % [v1, operator, v2]
      if a[i] == b[i]:
        #compare versions with the reset of the sequence
        let newA = a[(i + 1)..len(a) - 1].join(".")
        let newB = b[(i + 1)..len(b) - 1].join(".")
        if(newA == newB): return v1
        if maxLength == 1: return v1
        let r  = compareVersions($newA, operator, $newB)
        return "$1.$2" % [$a[i], r]
      elif comparator(a[i], operator, b[i]) == -1:
        return b.join(".")
      elif comparator(a[i], operator, b[i]) == 1:
        return a.join(".")
      i += 1
  except:
    echo "$1 $2 $3" % [v1, operator, v2]
    writeStackTrace()
    quit(-1)
    #raise newException(Error)

#TODO: modify this procedure to recieve the index in the VersionsTable of the versions will be compared
proc findGreatestOrEqual(srcTarget: string, versions: Table[string, string]): string =
  var target = srcTarget
  var result = ""
  let operator = ">="
  for key in versions.keys():
    result = compareVersions(target, operator, key)
    if target != result:
      target = result
  return result

proc findVersion(target: string, operator: string, versionsTable: Table[string, string]): string =
  if (operator == "<=" or operator == "=") and versionsTable.hasKey(target):
    return target
  elif operator == "<":
    var result = ""
    var smallerTable = initTable[string, string]()
    for key in versionsTable.keys():
      result = compareVersions(target, operator, key)
      if not smallerTable.hasKey(result):
        smallerTable.add(key, versionsTable[key])
    if len(smallerTable) > 0:
      return smallerTable[findGreatestOrEqual(target, smallerTable)]
  else:
    let foundVersion = findGreatestOrEqual(target, versionsTable)
    if not isNil foundVersion:
       return foundVersion
    else:
      echo "No best matching version found for recipe $1 $2" % [operator, target]

proc removeRevision(versions: Table[string, string]): Table[string, string] =
  var result = initTable[string, string]()
  for key in versions.keys():
    let newKey = key.substr(key.rfind("/") + 1, key.find("-r") - 1)
    result.add(newKey, versions[key])
  return result

proc removeNonFloat(versionStr: string): string =
  versionStr.replace(re"[^0-9.]+")

#[
`versionStr`: version reference
`operator`: how to compare to the reference version
`versionsTable`: url|file location of the pagacke|recipe, and its version
]#
proc findPreferredVersion*(versionStr: string, operator: string,
                          versionsTable: Table[string, string]): PreferredVersion =
  var versions = versionsTable
  # TODO: handle versionsTable == 0
  # the program was not found
  if len(versionsTable) == 0:
    echo "#######################################################################"
    echo  "ERROR: Recipe not found"
    echo "#######################################################################"
  try:
    let bestMatch = findVersion(versionStr, operator, versionsTable)
    echo "Best Match found $1" % [bestMatch]
    # some rare case: installed version is greatest than
    # versions on table, so it is not found in the table
    if not versionsTable.hasKey(bestMatch):
      # ignore requested version and send greatest in the table
      return findPreferredVersion("0", operator, versionsTable)
      
    let path = versions[bestMatch]
    echo "Best match is $1 : $2" % [bestMatch, path]
    return (bestMatch, path)
  except:
    for key in versions.keys():
      echo (key, ": ", versions[key])
    writeStackTrace()
    logError getCurrentExceptionMsg()
    raise getCurrentException()
    #quit(-1)
