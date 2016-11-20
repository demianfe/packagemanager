import os, strtabs, strutils, osproc, tables
import xmltree, httpclient, htmlparser, parsecfg
import streams, algorithm, sequtils

import ../utils/configuration
import ../utils/file
import ./versions

#initialize configuration
let conf = readConfiguration()

type
  Dependency* = object
    program*: string
    version*: string
    operator*: string
    flags*: seq[string]
    excludedVersions* : seq[string]

#recipe sections and their values
#type for the Recipe itself to be passed around
type
  Recipe* = object
    program*: string
    version*: string
    compile_version*: string
    url*: string
    file_size*: Biggestint
    file_md5*: string
    recipe_type*: string
    properties*: Table[string, string]
    configurations*: Table[string, seq[string]]
    functions*: Table[string, seq[string]]
    dependencies*: seq[Dependency]
    buildDependencies*: seq[Dependency]
    description*: Table[string, string]

type
  RecipeRef* = ref Recipe

proc `$`*(recipe: Recipe): string =
  if not isNil recipe.file_md5:
    let result: string = "$1, $2, $3" % [recipe.program, recipe.version, recipe.file_md5]
  else:
    let result: string = "$1, $2" % [recipe.program, recipe.version]

proc `$`*(recipe: RecipeRef): string =
  if not isNil recipe.file_md5:
    let result: string = "$1, $2, $3" % [recipe.program, recipe.version, recipe.file_md5]
  else:
    let result: string = "$1, $2" % [recipe.program, recipe.version]

proc parseDependencies(dependenciesString: string): seq[Dependency] =
  var dependenciesLines: seq[string] = split(dependenciesString, "\n")
  let depLen = len(dependenciesLines)
  var dependencies: seq[Dependency]
  newSeq(dependencies, 0)
  for line in dependenciesLines:
    var dep = Dependency()
    # GCC >= 4.2, != 4.3.2
    # gcc >= 4.2 but not 4.3.2
    var depLine = line.strip()
    if depLine.find("#") != -1:
      # dependency lines may contain comments
      # ignore everything that is after `#`
      depLine = depLine.substr(0, line.find("#") - 1)
    # use flags section
    # find `[` and `]` and make a list with everything
    # that is inside brackets separated by comma
    if depLine.find("[") != -1 and depLine.find("]") != -1:
      var useFlagsLine = depLine.substr(depLine.find("["), depLine.find("]"))
      useFlagsLine = useFlagsLine.replace("[","").replace("]", "")
      dep.flags = useFlagsLine.split(",")
      # remove this processed section so it does not interfere in further processing
      depLine = depLine.substr(0, line.find("[") - 1)
      depLine = depLine.substr(0, line.find("]") - 1)
    if depLine.len > 0:
      if depLine.find(" ") != -1:
        # version exclusion section
        if depLine.contains("!="): #depLine.find(",") != -1:
          # excluded versions are separated by comma and after operator `!=`
          if isNil dep.excludedVersions:
            dep.excludedVersions = @[]
          var exLine = split(depLine, "!=")
          exLine.delete(0)
          dep.excludedVersions = map(exLine, proc(x: string): string = x.strip())
          # remove from the comma onwards
          depLine = depLine.substr(0, line.find(",") - 1)
        let splitLine = split(depLine, " ")
        dep.program = splitLine[0]
        if depLine.find("<") != -1 or depLine.find(">") != -1 or depLine.find("=") != -1:
          #contains operator
          dep.operator = splitLine[1]
          dep.version = splitLine[2]
        else:
          dep.version = splitLine[1]
        dependencies.add(dep)
  return dependencies

proc parseRecipe(strFile: string): RecipeRef =  
  var recipe: RecipeRef = RecipeRef()
  recipe.properties = initTable[string, string]()
  recipe.configurations = initTable[string, seq[string]]()
  recipe.functions = initTable[string, seq[string]]()

  var prevFunc: bool = false #flag so we know we are reading a function
  var prevConf: bool = false #flag so we know we are reading a configuration
  var functionName: string
  var configurationName: string
  var lines: seq[string] = split(strFile, "\n")

  for currentLine in lines:
    #if line contans ´()´ is a function
    #if line contains only ´=(´ is a Compile configuration parameter
    #if line contains = is keyval like
    #this code may be too general
    if currentLine.len > 0 and not currentLine.startsWith("#"):
      #replace configuration variables
      let line = conf.replaceValues(currentLine).replace("\"","")
      #parses the recipe pairs of key=value attributes
      if (line.count("=") == 1) and (line.find("(") == -1) and
        (line.find(")") == -1) and prevFunc == false and prevConf == false:
        var
          name, value: string
        (name, value) = split(line, "=")
        recipe.properties.add(name.strip(), value)
        if name.strip == "recipe_type":          
          recipe.recipe_type = value
        elif name.strip == "url":
          recipe.url = value
        elif name.strip == "file_size":
          recipe.file_size = parseBiggestInt(value)
        elif name.strip == "file_md5":
          recipe.file_md5 = value
        elif name.strip == "compile_version":
          recipe.compile_version = value
              
      elif line.replace(" ","").find("()") != -1 and prevFunc == false and prevConf == false:
        #finds a functions and treat following lines as part of the function
        #until the `}` function block end is found
        prevFunc = true 
        functionName = line[0 .. line.find("()") - 1]
        recipe.functions.add(functionName, @[])
      elif prevFunc == true and line.strip().find("}") == 0:
        #TODO: add more controls to find end of block
        prevFunc = false
      elif prevFunc == true:
        for fName, currentValue in pairs recipe.functions:
          if fName == functionName:
            recipe.functions[fName].add(line.strip())
            break
      else:
        var replacedString: string = line.replace(" ", "")
        if replacedString.find("=(") != -1 and replacedString.find("=(")+2 == replacedString.len and prevConf == false:
          prevConf = true
          configurationName = line.strip().replace("=(", "")
          recipe.configurations.add(configurationName, @[])
        elif replacedString.find(")") == 0 and not prevFunc:
          replacedString = line.replace(")").strip() #warning
          if len(replacedString) > 0:
            recipe.configurations[configurationName].add(replacedString)
          prevConf = false
        elif prevConf:
         recipe.configurations[configurationName].add(line.strip())
  return recipe
  
proc parseDescription(descriptionString: string): Table[string, string] =
  const sections: array[5, string] = ["[Name]", "[Summary]",
                                      "[License]", "[Description]",
                                      "[Homepage]"]
  var index:int = 0
  var value: string
  var result = initTable[string, string]()
  let lines = descriptionString.split("\n")
  for line in lines:
    let section = line.subStr(line.find("["), line.find("]"))
    .replace("[", "")
    .replace("]", "")
    let value = line.subStr(line.find("]") + 1, len(line))
    result.add(section.strip(), value.strip())
  return result
  
proc getRecipeDirTree(dir: string): RecipeRef =
  #TODO: improve directory and file existence checking
  #reads the filepath and returns a the
  #directory files as strings
  var dependencies: Table[string, string]
  let recipeDir = dir & "/"
  var recipe: RecipeRef
  if os.dirExists(recipeDir):
    var resourcesDir:string = recipeDir & "Resources/"
    if os.fileExists(recipeDir & "Recipe"):
      recipe = parseRecipe(readFile(recipeDir & "Recipe"))
    if os.dirExists(resourcesDir):
      if os.fileExists(resourcesDir & "Description"):
        recipe.description = parseDescription(readFile(resourcesDir & "Description"))
      if os.fileExists(resourcesDir & "BuildDependencies"):
        recipe.buildDependencies = parseDependencies(readFile(resourcesDir & "BuildDependencies"))
        echo "TODO: BuildDependencies"
      if os.fileExists(resourcesDir & "BuildInformation"):
        echo "TODO: BuildInformation"
      if os.fileExists(resourcesDir & "Dependencies"):
        recipe.dependencies = parseDependencies(readFile(resourcesDir & "Dependencies"))
      if os.fileExists(resourcesDir & "Environment"):
        echo "TODO: Environment"
      #TODO: tasks
  return recipe

proc findRecipeURL(programName:string, version: string): string =
  #looks for a recipe in the recipe store 
  echo "Looking for recipe $program version $version" % ["program", programName, "version", version]
  let recipeStoreURL = conf.getSectionValue("compile","recipeStores")
  var client = newHttpClient()
  let response = client.get(recipeStoreURL)
  let html = parseHtml(newStringStream(response.body))
  var recipeUrl: string
  for a in html.findAll("a"):
    let href = a.attrs["href"]
    if not href.isNil:
      if href.toLower.find(programName.toLower()) != -1 and href.toLower.find(version.toLower) != -1:
        recipeUrl = recipeStoreURL & "/" & href
        break
  if recipeUrl.isNil:
    echo "Recipe for $program version $version was not found." % ["program", programName, "version", version]
  return recipeUrl
    
proc downloadAndExtractRecipe(url: string) = 
  var path = conf.getSectionValue("compile","packagedRecipesPath")
  
  let fileName = url.substr(url.rfind("/"), len(url) - 1)
  path = "$1$2" % [path, fileName]
  let filePath = localDownloadFile(url, path)
  echo unpackFile(filePath, conf.getSectionValue("compile","localRecipesPath"))

proc preferredVersion(version:string, operator: string,
                      versionsTable: Table[string, string]): PreferredVersion =
    return findPreferedVersion(version, operator, versionsTable)
   
proc findLocalRecipe(programName:string, version: string): RecipeRef =
  var recipe: RecipeRef
  for dir in walkDir(conf.getSectionValue("compile","localRecipesPath")):
    if existsDir(dir.path) and dir.path.toLower.find(programName.toLower) != -1:
      for subdir in walkDir(dir.path):
        if existsDir(subdir.path) and subdir.path.toLower.find(version.toLower) != -1:
          recipe = getRecipeDirTree(subdir.path)
          if not isNil recipe:
            #use part of the path as program name to keep camel case
            recipe.program = dir.path.substr(dir.path.rfind("/") + 1, len(dir.path))
            recipe.version = version
          break    
  return recipe

proc findLocalRecipe(program:string, operator:string, versionStr: string): RecipeRef =
  #TODO: use program name from the path
  var versionsTable: Table[string, string] = initTable[string, string]()
  let localRecipesPath = conf.getSectionValue("compile","localRecipesPath")
  for dir in walkDir(localRecipesPath):
    if existsDir(dir.path) and dir.path.toLower.find(program.toLower) != -1:
      for subdir in walkDir(dir.path):
        let currentVersion = subdir.path.substr(subdir.path.rfind("/") + 1, subdir.path.find("-r") - 1)
        versionsTable.add(currentVersion, subdir.path)
  
  if len(versionsTable) > 0:
    let preferredVersion = preferredVersion(versionStr, operator, versionsTable)
    if not isNil preferredVersion.path:
      var recipe = getRecipeDirTree(preferredVersion.path)
      if not isNil recipe:
        recipe.program = program
        recipe.version = $preferredVersion.version
      return recipe
      
# looks up for the best matching recipe in the recipe store
proc findRecipeUrl(program:string, operator:string, versionStr: string): PreferredVersion =
  echo "Searching for recipe $1 $2 in the remote repository" % [program, versionStr]
  var programVersions: seq[string] = @[]
  let recipeStoreURL = conf.getSectionValue("compile","recipeStores")
  # TODO: download recipe store file only once
  var html: XmlNode
  echo conf.getSectionValue("main", "debug")
  if conf.getSectionValue("main", "debug") != "true":
    var client = newHttpClient()
    let response = client.get(recipeStoreURL)
    html = parseHtml(newStringStream(response.body))
  else:
     html = loadHtml(conf.getSectionValue("main", "cachedRecipeStore"))
  
  for a in html.findAll("a"):
    let href = a.attrs["href"]
    if not href.isNil:
      var currentProgram = href.toLower.substr
      currentProgram = currentProgram.substr(currentProgram.rfind("/"),
                                             currentProgram.find("--") - 1)
      if currentProgram == program.toLower():
        let recipeUrl = recipeStoreURL & "/" & href
        programVersions.add(recipeUrl)

  var versionsTable: Table[string, string] = initTable[string, string]()
  for pv in programVersions:
    let recipeVersion = pv.split("--")[1]
    if isDigit(recipeVersion[0]):
      let v = recipeVersion.split("-")[0]
      versionsTable.add(v, pv)
  let preferredVersion = preferredVersion(versionStr, operator, versionsTable)
  return preferredVersion

#TODO: look for the recipe remotely first but do not download it.
#TODO: lookup if is not locally packaged
proc findRecipe*(program: string, operator: string, versionStr: string): RecipeRef =
  echo "Looking for $1 $2 $3" % [program, operator, versionStr]  
  #find best version remotely
  # look for best recipe version locally
  # if not found, download recipe
  let preferredVersion = findRecipeUrl(program, operator, versionStr)
  if not isNil preferredVersion.path:
    #return file path or at least preferred version
    var recipe: RecipeRef = findLocalRecipe(program, preferredVersion.version)
    if isNil recipe:
      downloadAndExtractRecipe preferredVersion.path
      recipe = findLocalRecipe(program, preferredVersion.version)
    return recipe
  
proc findRecipe*(program: string, version: string): RecipeRef =
  var recipe: RecipeRef = findLocalRecipe(program, version)
  if isNil recipe:
    echo "Recipe not found whitn local recipes. Looking remotely."
    let recipeURL = findRecipeURL(program, version)
    if not isNil recipeURL:
    #lookup for the extracted recipe in the recipes directory
      downloadAndExtractRecipe recipeURL
      recipe = findLocalRecipe(program, version)
  return recipe

proc findRecipe*(dependency: Dependency): RecipeRef =
  if isNil dependency.operator:
    var recipe = findRecipe(dependency.program, dependency.version)
    #if the extact version is not found look for a newer version
    if isNil recipe:
      recipe = findRecipe(dependency.program, ">=", dependency.version)
    return recipe
  else:
    return findRecipe(dependency.program, dependency.operator, dependency.version)
