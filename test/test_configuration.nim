import strutils, parsecfg, tables

import ../src/utils/configuration

var conf = readConfiguration()
let value = "http://$ftpgnu/ncurses/ncurses-5.5.tar.gz"
var url = value
#echo conf.getSectionValue("repository", "ftpgnu")
echo conf.replaceValues(value)

for sectionKey in conf.keys():
  var section = conf[sectionKey]
  echo "======= $1 =======" % sectionKey
  for itemKey in section.keys():
    var value = section[itemKey]
    echo "$1: $2" % [itemKey, value]
  echo "================="

