import ../src/utils/configuration
import Tables

var conf = readConfiguration()

for k in conf.keys():
  echo k & " = " & conf[k]
