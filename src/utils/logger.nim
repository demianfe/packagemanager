import logging, parsecfg
import configuration

let conf = readConfiguration()
let varDir = conf.getSectionValue("compile","variablesDir")
echo varDir
let logFile = varDir & "/log/packagemanager.log"
var fileLogger = newFileLogger(logFile, fmtStr = verboseFmtStr)
addHandler(fileLogger)

proc logToFile*(message: string) =
  info(message)
