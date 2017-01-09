import strutils, parsecfg

import ../src/utils/configuration


var conf = readConfiguration()

let value = "http://$ftpgnu/ncurses/ncurses-5.5.tar.gz"

var url = value
#echo conf.getSectionValue("repository", "ftpgnu")
echo conf.replaceValues(value)
