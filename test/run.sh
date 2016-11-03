#a simple shell script to run our tests

#test recipe
nim -o:bin/test/test_recipe c -r test/test_recipe.nim
#test compile
#nim -o:bin/test/test_compile c -r test/test_compile.nim emacs 24.3
