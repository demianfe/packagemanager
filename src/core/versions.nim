#procs that help package version handling
import tables, sequtils, algorithm, strutils

type
  PreferredVersion* = tuple[version: string, path: string]

proc `$`*(preferredVersion: PreferredVersion): string =
  return preferredVersion.version & " : " & preferredVersion.path

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

proc compareVersions(v1: string, operator: string, v2: string): string =
  #compare a sequence of int values using intComparator
  var a = map(v1.split("."), proc(x: string): int = parseInt(x))
  let b = map(v2.split("."), proc(x: string): int = parseInt(x))
  var i = 0
  var maxLength = len(a)
  #use the shortest array as max
  if maxLength > len(b): maxLength = len(b)
  while i < maxLength:
    if a[i] == b[i]:
      #compare versions with the reset of the sequence
      let newA = a[(i + 1)..len(a) - 1].join(".")
      let newB = b[(i + 1)..len(b) - 1].join(".")
      if(newA == newB): return v1
      let r  = compareVersions($newA, operator, $newB)
      return "$1.$2" % [$a[i], r]
    elif intComparator(a[i], operator, b[i]) == -1:
      return b.join(".")
    elif intComparator(a[i], operator, b[i]) == 1:
      return a.join(".")
    i += 1

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
    return versionsTable[target]
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
      echo "Best matching version not found for recipe $1 $2" % [operator, target]

proc removeRevision(versions: Table[string, string]): Table[string, string] =
  var result = initTable[string, string]()
  for key in versions.keys():
    let newKey = key.substr(key.rfind("/") + 1, key.find("-r") - 1)
    result.add(newKey, versions[key])
  return result

proc findPreferedVersion*(version: string, operator: string, versions: Table[string, string]): PreferredVersion =
  let bestMatch = findVersion(version, operator, versions)
  echo "BEST MACH ---> $1" % bestMatch
  
  let path = versions[bestMatch]
  return (bestMatch, path)

