import os
import strutils

import ../src/core/compile

proc testCompile() =  
  when declared(commandLineParams):
    # Use commandLineParams() here
    var arguments: seq[string] = @[]
    var compileParams:seq[string] = @[]
    for param in commandLineParams():
      if param.find("--") == 0:
        arguments.add(param)
      else:
        compileParams.add(param)
      #expectedly first compileparams should be the program to compile
      #and the seccond should be its version
    if len(compileParams) >= 2:
      echo compileParams[0] & " = "  & compileParams[1]
      compile(compileParams[0], compileParams[1])
    else:
      echo compileParams[0]
      compile(compileParams[0], nil)
   
  else:
    # Do something else!
    echo "No arguments"

testCompile()
