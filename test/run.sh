#a simple shell script to run our tests
clear
#nim -o:bin/test/test_configuration c -r test/test_configuration.nim

#test file
#nim -o:bin/test/test_file c -r test/test_file.nim

#test recipe
#nim -o:bin/test/test_recipe c -r test/test_recipe.nim

#test compile
#nim -o:bin/test/test_compile c -r test/test_compile.nim emacs 24.3

#test version
#nim -o:bin/test/test_package_version c -r test/test_package_version.nim

#test package manager
nim -o:bin/packagemanager c -r src/packagemanager.nim $1 $2
