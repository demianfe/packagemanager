#a simple shell script to run our tests

#test compile
nim -o:bin/test_compile c -r test/test_compile.nim nano 2.7.0 
