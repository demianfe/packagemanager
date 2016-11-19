import os, osproc, tables, strutils, parsecfg
import recipe, recipespecs, algorithm

import ../utils/configuration
import ../utils/file

#initialize configuration
let conf = readConfiguration()

proc prepareInstall(recipe: RecipeRef): string = 
  #create $programsPath/recpe.program/recipe.version
  let programsPath = conf.getSectionValue("compile","programsPath")
  let target = "$programsPath/$program/$version" % ["programsPath", programsPath,
                                                  "program", recipe.program,
                                                  "version", recipe.version]
  let command = "mkdir -p $target" % ["target", target]
  echo execProcess(command)
  return target
  
### make file
proc buildTypeMakeFile(recipe: RecipeRef, path: string) =
  #TODO: handle unmanaged files
  setCurrentDir(path)
  echo execProcess("make")
  echo execProcess("make install")

### build type section
proc buildTypeConfigure(recipe: RecipeRef, path: string) =
  #TODO: replace variables
  #read/load all configuration/installation parameters   
  #check if it uses autogen.sh
  #change ./configure mode to +x
  #check "$needs_build_directory" = "yes" this builds in another directory (?)
  let programsPath = conf.getSectionValue("compile","programsPath")
  let target = prepareInstall(recipe)
  var command = "configure --prefix=$target" % ["target", target]
  #verify that ./configure exists
  echo "Changing dir to " & path 
  setCurrentDir(path)
  if existsFile(path & command):
    echo execProcess("chmod +x $file ") % ["file", path & command]
  if recipe.configurations.hasKey("configure_options"):
    for option in recipe.configurations["configure_options"]:
      command = command & " " & conf.replaceValues(option)
  command = "./" & command
  echo execProcess(command)
 
proc compileProgram(recipe: RecipeRef) =
    let packagesDir = conf.getSectionValue("compile","packagesPath")
    let archivesPath = conf.getSectionValue("compile","archivesPath")
    var url = recipe.url
    if isNil url:
      url = recipe.configurations["urls"][0]
      
    let splitUrl = rsplit(url,"/")
    let fileName = splitUrl[len(splitUrl) - 1]
    var filePath = packagesDir & "/" & fileName
    echo ("path ",filePath)
    echo ("filename ", fileName)
    if not checkFile(filePath, recipe.file_size, recipe.file_md5):
      filePath = localDownloadFile(url, filePath)
    discard unpackFile(filePath, archivesPath)
    #compile
    #call the correct recipeType compile procedure
    if recipe.recipe_type.cmpIgnoreCase("configure") == 0:
      var unpackedDir = fileName.rsplit("-" & recipe.version)[0]
      #improve this wild guessing
      unpackedDir = archivesPath & "/" & unpackedDir & "-" & recipe.version
      buildTypeConfigure(recipe, unpackedDir)
      buildTypeMakeFile(recipe, unpackedDir)

proc loadDependencies(recipe: RecipeRef,
                      recipesTable: var OrderedTable[string, RecipeRef]):
                      OrderedTable[string, RecipeRef] =
  #given a recipe load al recipes needed to compile
  for dep in recipe.dependencies:
    # hash the name+version ?
    let recipeKey = dep.program&dep.version
    let dependedRecipe = findRecipe(dep)
    if not recipesTable.hasKey(recipeKey):
      recipesTable.add(recipeKey, dependedRecipe)
    if not isNil dependedRecipe:
      if len(dependedRecipe.dependencies) > 0:
        echo "Loading depencies for recipe $1 version: $2" % [recipe.program, recipe.version]
        recipesTable = loadDependencies(dependedRecipe, recipesTable)
      else:
        echo "Recipe not found for $1 version: $2" % [dependedRecipe.program,
                                                      dependedRecipe.version]
  return recipesTable

proc compile*(program: string, version: string) =
  #load all recipes from dependencies list to a seq
  #iterate and compile each item
  var recipe: RecipeRef
  var recipes: OrderedTable[string, RecipeRef] = initOrderedTable[string, RecipeRef]()
  if isNil version:
    recipe = findRecipe(program, ">", "0.0")
  else:
    recipe = findRecipe(program, "=", version)

  recipes.add(recipe.program&recipe.version, recipe)
  
  if not isNil recipe:
    #TODO: check if $Program/$version is already installed
    #iterate over the dependencies of the dependencies...
    recipes = loadDependencies(recipe, recipes)
    #reverse order of compilation
    var keySeq: seq[string] = @[]
    for key in recipes.keys():
      keySeq.add(key)
    for key in keySeq.reversed():
      let currentRecipe = recipes[key]
      echo "Compiling $1 $2"  % [currentRecipe.program, currentRecipe.version]
      compileProgram(currentRecipe)
  else:
    echo "Recipe not found"
