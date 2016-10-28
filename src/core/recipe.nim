import os, strtabs, strutils, osproc, tables
import xmltree, httpclient, htmlparser, parsecfg
import streams

import ../utils/configuration
import ../utils/file

#initialize httpclient
var client = newHttpClient()
#initialize configuration
let conf = readConfiguration()

#recipe sections and their values
#type for the Recipe itself to be passed around
type
  Recipe* = ref object
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
    dependencies*: Table[string, string]
    buildDependencies*: Table[string, string]
    description*: Table[string, string]
        
proc parseDependencies(dependenciesString: string): Table[string, string] =
  #TODO: handle useflgs
  #TODO: dependencies have minor and mayor versions
  var depsTable = initTable[string, string]()
  var dependencies: seq[string] = split(dependenciesString, "\n")
  for dep in dependencies:
    if dep.len > 0:
      var
        k,v: string
      if dep.find(" ") != -1:
        (k,v) = split(dep, " ")
        depsTable.add(k, v)
      else:
        depsTable.add(dep.strip(),"")
  return depsTable

proc parseRecipe(strFile: string): Recipe =
  #this prodecedure will call other procedures
  #to gather all recipe information needed on the
  #different stages of the build process.
  #var result: Recipe
  var recipe: Recipe = Recipe()
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
  
proc getRecipeDirTree(dir: string): Recipe =
  #TODO: improve directory and file existence checking
  #reads the filepath and returns a the
  #directory files as strings
  var dependencies: Table[string, string]
  let recipeDir = dir & "/"
  var recipe: Recipe
  if os.dirExists(recipeDir):
    var resourcesDir:string = recipeDir & "Resources/"
    if os.fileExists(recipeDir & "Recipe"):
      recipe = parseRecipe(readFile(recipeDir & "Recipe"))
    if os.dirExists(resourcesDir):
      if os.fileExists(resourcesDir & "Description"):
        recipe.description = parseDescription(readFile(resourcesDir & "Description"))
      if os.fileExists(resourcesDir & "BuildDependencies"):
        #echo readFile(resourcesDir & "BuildDependencies")
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
  let path = conf.getSectionValue("compile","packagedRecipesPath")
  let filePath = localDownloadFile(url, path)
  echo unpackFile(filePath, conf.getSectionValue("compile","localRecipesPath"))

proc findLocalRecipe(programName:string, version: string): Recipe =
  var recipe:Recipe
  for dir in walkDir(conf.getSectionValue("compile","localRecipesPath")):
    if existsDir(dir.path) and dir.path.find(programName) != -1:
      for subdir in walkDir(dir.path):      
        if existsDir(subdir.path) and subdir.path.find(version) != -1:
          recipe = getRecipeDirTree(subdir.path)
          break
  if not isNil recipe:
    recipe.program = programName
    recipe.version = version
  return recipe
  
proc findRecipe*(programName:string, version: string): Recipe =
  #TODO: recipe might be as packaged recipe
  #recipes are normaly uses the first letter in upper case.
  #for now capitalize the program name
  let program = capitalize programName
  var recipe: Recipe = findLocalRecipe(program, version)
  if isNil recipe:
    let recipeURL = findRecipeURL(program, version)
    if not isNil recipeURL:
    #lookup for the extracted recipe in the recipes directory
      downloadAndExtractRecipe recipeURL
      recipe = findLocalRecipe(program, version)
  return recipe
