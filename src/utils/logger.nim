import logging, parsecfg, strutils
import configuration

let conf = readConfiguration()
let varDir = conf.getSectionValue("compile","variablesDir")
echo varDir
let logFile = varDir & "/log/packagemanager.log"
var fileLogger = newFileLogger(logFile, fmtStr = verboseFmtStr)
addHandler(fileLogger)

proc logToFile*(msg: string) =
  if conf.getSectionValue("main", "debug").cmpIgnoreCase("true") == 0:
    info(msg)

proc logError*(msg: string) =
  error("================== ERROR ==================")
  error(msg)
  error("===========================================")
