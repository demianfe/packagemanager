import os, osproc, tables, strutils, parsecfg
import recipe, recipespecs, algorithm, logging

import ../utils/configuration
import ../utils/file

#initialize configuration
let conf = readConfiguration()
#logger
var fileLogger = newFileLogger("test/test.log", fmtStr = verboseFmtStr)
var consoleLogger = newConsoleLogger()
addHandler(fileLogger)

proc prepareInstall(recipe: RecipeRef): string = 
  #create $programsPath/recpe.program/recipe.version
  let programsPath = conf.getSectionValue("compile","programsPath")
  # let target = "$programsPath/$program/$version" % ["programsPath", programsPath,
  #                                                 "program", recipe.program,
  #                                                 "version", recipe.version]
  let target = programsPath / recipe.program / recipe.version
  let command = "mkdir -p $target" % ["target", target]
  echo "Creating target dir $1" % command
  echo execProcess(command)
  return target

### build type section  
### makefile
proc buildTypeMakeFile(recipe: RecipeRef, path: string) =
  #TODO: handle unmanaged files
  echo "path -- $1 " % path
  setCurrentDir(path)
  echo execProcess("make")
  echo execProcess("make install")

proc buildTypeConfigure(recipe: RecipeRef, path: string) =
  #TODO: replace variables
  #read/load all configuration/installation parameters   
  #check if it uses autogen.sh
  #change ./configure mode to +x
  #check "$needs_build_directory" = "yes" this builds in another directory (?)
  let
    programsPath = conf.getSectionValue("compile","programsPath")
    target = prepareInstall(recipe)
    ctarget = "--prefix=$target" % ["target", target]
  var command = "./configure"
  #verify that ./configure exists
  echo "Changing dir to " & path 
  setCurrentDir(path)
  var args = @[target]
  if existsFile(path & command):
    echo execProcess("chmod +x $file") % ["file", path & command]
  if recipe.configurations.hasKey("configure_options"):
    for option in recipe.configurations["configure_options"]:
      args.add(conf.replaceValues(option))
  command = "."  / command
  let resultCode = callCommand(command=command, workingDir=path, args=args)
  if resultCode == -1:
    #remove created
    echo "excuting rm -rf $target" % target
    #execProcess("rm -rf $target" % target)
    echo "Failed to compile $1 $2" % [recipe.program, recipe.version]
    quit(-1)
 
proc compileProgram(recipe: RecipeRef) =
  let packagesDir = conf.getSectionValue("compile","packagesPath")
  let archivesPath = conf.getSectionValue("compile","archivesPath")
  var url = recipe.url
  if isNil url:
    url = recipe.configurations["urls"][0]

  let splitUrl = rsplit(url,"/")
  let fileName = splitUrl[len(splitUrl) - 1]
  var filePath = packagesDir & "/" & fileName
  if not checkFile(filePath, recipe.file_size, recipe.file_md5):
    filePath = localDownloadFile(url, packagesDir, fileName)
    var p = unpackFile(filePath, archivesPath)
    #call the correct recipeType compile procedure
  if recipe.recipe_type.cmpIgnoreCase("configure") == 0:
    var unpackedDir = fileName.rsplit("-" & recipe.version)[0]
    #improve this wild guessing
    unpackedDir = archivesPath / unpackedDir
    #TODO: do something with the with the output
    discard unpackedDir
    buildTypeConfigure(recipe, unpackedDir)
    # buildTypeMakeFile(recipe, unpackedDir)

proc loadDependencies(recipe: RecipeRef, recipes: var OrderedTable[string, RecipeRef]):
                     OrderedTable[string, RecipeRef] =
  
  for d in recipe.dependencies:
    echo "Looking recipe for $1 $1" % [d.program, d.version]
    var r = findRecipe(d)
    recipes.add(r.program, r)
  return recipes

#TODO: generalize this procedure
proc findProgramVersion(program: string, version: string, path: string): string =
  var result: string
  for dir in walkDir(path):
    if existsDir(dir.path) and dir.path.toLower.find(program.toLower) != -1:
      for subdir in walkDir(dir.path):
        echo subdir.path
        if existsDir(subdir.path) and subdir.path.toLower.find(version.toLower) != -1:
          result = subdir.path
          break
  return result
  
proc compile*(program: string, version: string) =
  #load all recipes from dependencies list to a seq
  #iterate and compile each item
  var recipe: RecipeRef
  var recipes: OrderedTable[string, RecipeRef] = initOrderedTable[string, RecipeRef]()
  var dep = Dependency()
  dep.program = program
  dep.version = version
  if isNil version:
    dep.version = "0.0"
  else:
    dep.operator = ">="
  recipe = findRecipe(dep)
  recipes.add(recipe.program, recipe)
  
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
      #FIXME: ignoring recipeType = meta, handle this in the future
      if currentRecipe.recipe_type.strip() == "meta":
        echo "WARNING:"
        echo "Ignoring recipe type meta for $1" % currentRecipe.program
      elif not isNil findProgramVersion(currentRecipe.program,
                                        currentRecipe.version,
                                        conf.getSectionValue("main","programs")):
         echo "Program $1 $2 already installed."  % [currentRecipe.program, currentRecipe.version]
      else:
        echo "------------------------------------------------------------------"
        echo "Compiling $1 $2"  % [currentRecipe.program, currentRecipe.version]
        
        echo "Compile type $1" % currentRecipe.recipe_type
        echo "------------------------------------------------------------------"
        compileProgram(currentRecipe)
  else:
    echo "Recipe not found"
