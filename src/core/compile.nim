import os, osproc, tables, strutils, parsecfg
import recipe, recipespecs

import ../utils/configuration
import ../utils/file

#initialize configuration
let conf = readConfiguration()

proc prepareInstall(recipe: Recipe): string = 
  #create $programsPath/recpe.program/recipe.version
  let programsPath = conf.getSectionValue("compile","programsPath")
  let target = "$programsPath/$program/$version" % ["programsPath", programsPath,
                                                  "program", recipe.program,
                                                  "version", recipe.version]
  let command = "mkdir -p $target" % ["target", target]
  echo execProcess(command)
  return target
  
### make file
proc buildTypeMakeFile(recipe: Recipe, path: string) =
  #TODO: handle unmanaged files
  setCurrentDir(path)
  echo execProcess("make")
  echo execProcess("make install")

### build type section
proc buildTypeConfigure(recipe: Recipe, path: string) =
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
    
  for option in recipe.configurations["configure_options"]:  
    command = command & " " & conf.replaceValues(option)

  command = "./" & command
  echo execProcess(command)
 
proc compile*(program: string, version: string) =
  var recipe: Recipe = findRecipe(program, version)
  if not isNil recipe:
    let packagesDir = conf.getSectionValue("compile","packagesPath")
    let archivesPath = conf.getSectionValue("compile","archivesPath")
    let splitUrl = rsplit(recipe.url,"/")
    let fileName = splitUrl[len(splitUrl) - 1]
    var filePath = packagesDir & "/" & fileName
    
    if not checkFile(filePath, recipe.file_size, recipe.file_md5):
      filePath = localDownloadFile(recipe.url, filename)
    discard unpackFile(filePath, archivesPath)
    #compile
    #call the correct recipeType compile procedure
    if recipe.recipe_type.cmpIgnoreCase("configure") == 0:
      var unpackedDir = fileName.rsplit("-" & recipe.version)[0]
      #improve this wild guessing
      unpackedDir = archivesPath & "/" & unpackedDir & "-" & recipe.version
      buildTypeConfigure(recipe, unpackedDir)
      buildTypeMakeFile(recipe, unpackedDir)
    else:
      echo "Recipe not found"
