import os, httpclient, htmlparser, parsecfg
import xmltree, strtabs, strutils, osproc

import ../utils/configuration
import recipe

var client = newHttpClient()
let conf = readConfiguration()

proc findRecipeURL(programName:string, version: string): string =
  #looks for a recipe in the recipe store 
  echo "Looking for recipe $program version $version" % ["program", programName, "version", version]
  
  let repositoryURL = conf.getSectionValue("compile","recipeStores")
  #let response = client.get(url)
  const url = "/Data/devel/projects/demian/packagemanager/resources/Index_of_recipe-store.html"
  let html = loadHtml(url)
  var recipeUrl: string
  for a in html.findAll("a"):
    let href = a.attrs["href"]
    if not href.isNil:
      if href.toLower.find(programName.toLower()) != -1 and href.toLower.find(version.toLower) != -1:
        recipeUrl = repositoryURL & "/" & href
        break
  if recipeUrl.isNil:
    echo "Recipe for $program version $version was not found." % ["program", programName, "version", version]
  return recipeUrl
    
proc downloadAndExtractRecipe(url: string) = 
  let splitUrl = rsplit(url,"/")
  let fileName = splitUrl[len(splitUrl) - 1]
  let downloadedFilName = "$path/$fileName" % ["path", conf.getSectionValue("compile","packagedRecipesPath"),
                                    "fileName", fileName]
  #set timeout to 1 min
  downloadFile(url, downloadedFilName, timeout=60000)
  #unpack it to localRecipes
  let unpackCommand = "tar xf $recipePath -C $targetDir" % ["recipePath", downloadedFilName,
                                                             "targetDir", conf.getSectionValue("compile","localRecipesPath")]
  echo "Extracting recipe."
  discard execProcess(unpackCommand)

proc findLocalRecipe(programName:string, version: string): Recipe =
  for dir in walkDir(conf.getSectionValue("compile","localRecipesPath")):
    if existsDir(dir.path) and dir.path.find(programName) != -1:
      for subdir in walkDir(dir.path):
        if existsDir(subdir.path) and subdir.path.find(version) != -1:
          echo "reading " & subdir.path
          var recipe: Recipe = getRecipeDirTree subdir.path

proc findRecipe*(programName:string, version: string): Recipe =
  #TODO: look into localRecipes first
  var recipe: Recipe = findLocalRecipe(programName, version)
  if not isNil recipe :
    let recipeURL = findRecipeURL(programName, version)
    if not isNil recipeURL:
    #lookup for the extracted recipe in the recipes directory
      downloadAndExtractRecipe recipeURL
      recipe = findLocalRecipe(programName, version)
