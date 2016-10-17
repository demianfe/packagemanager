import os

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

echo "about to call "
echo getRecipeDirTree(recipeDir)
