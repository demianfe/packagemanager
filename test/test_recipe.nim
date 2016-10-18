import os
import tables

import ../src/core/recipe

var baseProjectDir = os.getCurrentDir() & "/../"
#base recipe dir, should be a global variable from a configuration file
var recipesDir: string = baseProjectDir & "/resources/Recipes/"
#specific recipe directory
var recipeDir:string = recipesDir & "Linux/3.13.3-r1/"#"OpenSSH/7.1p1-r1/" 
#resources sub directory
var resourcesDir:string = recipeDir & "Resources/"

#maybe use a tuple or something more structured
var recipeString: string

var r = getRecipeDirTree(recipeDir)
echo "Recipe " & $r

# var pair: tuple[key: string, val:Table[string, seq[string]]]
# for pair in pairs(r.functions):
#   echo pair[0] & " - " & pair[1]

# for pair in pairs(r.configurations):
#   echo "conf: " & pair[0] & " - " & pair[1]
  
