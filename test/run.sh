#a simple shell script to run our tests

#test recipe
#nim -o:bin/test/test_recipe c -r test/test_recipe.nim

#test compile
nim -o:bin/test/test_compile c -r test/test_compile.nim emacs

#test version
#nim -o:bin/test/test_package_version c -r test/test_package_version.nim
