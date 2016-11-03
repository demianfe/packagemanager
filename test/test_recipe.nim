import os, tables, strutils

import ../src/core/recipe

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

testRecipeVersions()
