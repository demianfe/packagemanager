import os, tables, strutils

import ../src/core/recipe
import ../src/utils/file

proc testRecipeVersions() =  
  discard findRecipe("Ncurses", ">=", "5.0")
  echo "-------------------------------------"
  discard findRecipe("Ncurses", ">", "5.4")
  echo "-------------------------------------"
  discard findRecipe("Ncurses", "<=", "5.4")
  echo "-------------------------------------"
  discard findRecipe("Ncurses", "<", "5.4")

proc testRecipeFinder() =
  #existing recipe
  echo "Existing recipe"
  echo $(not isNil findRecipe("Emacs", "24.3"))
  #unexisting recipe
  echo "Unexisting recipe"
  echo $(isNil findRecipe("Emacs", "25.3"))

proc testRecipeSections() =
  let recipe = findRecipe("glibc", "2.15")
  echo recipe.properties
  echo recipe.configurations

proc testRecipeUtils() =
  echo findRecipeURL("nano", "2.7.0")

testRecipeUtils()
