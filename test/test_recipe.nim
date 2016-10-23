import os, tables, strutils

import ../src/core/recipe
import ../src/core/recipeutils

const url = "/Data/devel/projects/demian/packagemanager/resources/Index_of_recipe-store.html"

proc test_recipeParser() = 
  var baseProjectDir = os.getCurrentDir() & "/../"
  var recipesDir: string = baseProjectDir & "/resources/Recipes/"
  var recipeDir:string = recipesDir & "Linux/3.13.3-r1/"#"OpenSSH/7.1p1-r1/" 
  var r = getRecipeDirTree(recipeDir)
  echo "Found Recipe: " & $(r.buildDependencies)

proc test_recipeFinder() =
  #existing recipe
  echo "Existing recipe"
  echo $(not isNil findRecipe("Emacs", "24.3"))
  #unexisting recipe
  echo "Unexisting recipe"
  echo $(isNil findRecipe("Emacs", "25.3"))
  
test_recipeFinder()

