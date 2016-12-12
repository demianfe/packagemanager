import os, osproc, tables, strutils, parsecfg, sequtils
import recipe, algorithm, logging

import ../utils/configuration
import ../utils/file

#initialize configuration
let conf = readConfiguration()
#logger
var fileLogger = newFileLogger("test/test.log", fmtStr = verboseFmtStr)
var consoleLogger = newConsoleLogger()
addHandler(fileLogger)

proc buildFail(recipe: RecipeRef, target: string) =
  echo "Removing $1 " % target
  echo "Failed to compile $1 $2" % [recipe.program, recipe.version]
  discard execProcess("rm -rf $1" % target)
  writeStackTrace()
  echo getCurrentExceptionMsg()
  quit(-1)

proc prepareInstall(recipe: RecipeRef): string = 
  #create $programsPath/recpe.program/recipe.version
  let
    programsPath = conf.getSectionValue("compile","programsPath")
    target = programsPath / recipe.program / recipe.version
  discard execProcess("rm -rf $1" % [target])
  echo "Creating target dir $1" % [target]
  discard execProcess("mkdir -p $1" % [target])
  return target

### build type section  
### makefile
proc buildTypeMakeFile(recipe: RecipeRef, path, target: string): int =
  #TODO: handle unmanaged files
  echo "path -- $1 " % path
  try:
    setCurrentDir(path)
    var (code, output) = callCommand(command="make", workingDir=path)
    if code != 0:
      buildFail(recipe, target)
      return code
    (code, output) = callCommand(command="make", workingDir=path, args=["install"])
    if code != 0:
      buildFail(recipe, target)
      return code
  except OSError:
    buildFail(recipe, target)

proc buildTypeConfigure(recipe: RecipeRef, path, target: string) =
  #TODO: replace variables
  #read/load all configuration/installation parameters   
  #check if it uses autogen.sh
  #change ./configure mode to +x
  let programsPath = conf.getSectionValue("compile","programsPath")
  let prefix = "--prefix=$target" % ["target", target]
  var buildPath = path
  var command = "./configure"
  if recipe.properties.contains("needs_build_directory") and recipe.properties["needs_build_directory"] == "yes":
    buildPath = path / "build"
    command = ".$1" % command
  var args = newSeq[string]()
  try:
    echo "Changing dir to " & path
    setCurrentDir(path)
    if existsFile(path & command):
      echo execProcess("chmod +x $file") % ["file", path & command]
    if recipe.configurations.hasKey("configure_options"):
      args = recipe.configurations["configure_options"]
    # `args.add(prefix)` does not work here, why?
    args.insert(prefix)
    let (resultCode, output) = callCommand(command=command, workingDir=buildPath, args=args)
    if resultCode != 0:
      buildFail(recipe, target)
  except OSError:
    buildFail(recipe, target)
 
proc compileProgram(recipe: RecipeRef) =
  let
    packagesDir = conf.getSectionValue("compile","packagesPath")
    archivesPath = conf.getSectionValue("compile","archivesPath")
  var url = recipe.url
  
  if isNil url:
    #TODO: iterate over urls
    url = recipe.configurations["urls"][0]
  url = url.replace("\"","")
  let
    splitUrl = rsplit(url,"/")
    fileName = splitUrl[len(splitUrl) - 1].replace("\"","")
  var filePath = packagesDir / fileName
  if not checkFile(filePath, recipe.file_size, recipe.file_md5):
    let (code, output) = download(url, packagesDir, fileName)
  var unpackedDir = fileName.rsplit("-" & recipe.version)[0]
  #improve this wild guessing
  unpackedDir = archivesPath / unpackedDir & "-" & recipe.version
  var p = unpackFile(filePath, archivesPath)
  #call the correct recipeType compile procedure
  let target = prepareInstall(recipe)
  if recipe.recipe_type.cmpIgnoreCase("configure") == 0:
    buildTypeConfigure(recipe, unpackedDir, target)
    var code = buildTypeMakeFile(recipe, unpackedDir, target)

proc loadDependencies(recipe: RecipeRef, recipes: var OrderedTable[string, RecipeRef]):
                     OrderedTable[string, RecipeRef] =
  for d in recipe.dependencies:
    echo "Looking recipe for $1 $1" % [d.program, d.version]
    var r = findRecipe(d.program, d.version)
    if isNil r:
      echo "Recipe cannot be nil at this point."
      echo "Failed to find recipe $1 $2" % [d.program, d.version]
      writeStackTrace()
      echo getCurrentExceptionMsg()
      quit(-1)
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
