import os, osproc, strutils, strtabs, httpclient, checkmd5, streams
import logger
 
proc extractFilename*(url: string): string  =
  let
    splitUrl = rsplit(url,"/")
    fileName = splitUrl[len(splitUrl) - 1]
  return filename

proc correctPath*(dir, target: string): string =
  # looks for the exactMatching folder or file
  # ignoring case sensitivity
  for entry in walkDir(dir):
    let targetPath = dir / target
    if entry.path.cmpIgnoreCase(targetPath) == 0:
      return entry.path

proc which*(command: string): string =
  #finds the command in path
  findExe(command)
  
proc callCommand*(command:string, workingDir: string = "", args: openArray[string] = []):
                (int, seq[string]) =
  #convient way to call startProcess and handle output
  let options: set[ProcessOption] = {poEchoCmd, poUsePath, poStdErrToStdOut}
  var
    result: seq[string] = @[]
    p = startProcess(command=command, workingDir=workingDir, args=args, options=options)
    pStdout = p.outputStream()
    line: TaintedString = ""
    outLines: seq[string] = @[]
  while p.peekExitCode == -1:
    if readLine(pStdout, line):
      logToFile line
      outLines.add(line)
  echo "Exiting with code $1" % $p.peekExitCode
  p.close
  if p.peekExitCode != 0:
    writeStackTrace()
    quit(-1)
  return (p.peekExitCode, outLines)
  
proc download*(url, destination: string, filename: string=nil): (int, seq[string])  =
  let command = which "wget"
  var args: seq[string]
  # if not isNil filename:
  #   let fileDestination: string = destination / filename
  #   args = @["-O", fileDestination, url]
  # else:
  args = @[url, "--directory-prefix=" & destination] 
  return callCommand(command=command, workingDir="/", args=args)

#depreacte
proc localDownloadFile*(url, path: string, timeout=6000000): string {.deprecated.} =
  echo "downloading $1" % [url]
  echo download(url, path)
  return path

proc localDownloadFile*(url, path, filename: string, timeout=6000000): string {.deprecated.}=
  echo "Downloading $1 into $2" % [url, path]
  discard download(url, path)
  return path / filename
  
proc unpackFile*(packagePath, targetDir: string): (int, seq[string]) =
  let
    #TODO: take the lines from output and lookup for the file name
    command = which "tar"
    args = @["vvxf", packagePath, "-C", targetDir]
  callCommand(command=command, workingDir=targetDir, args)
  
proc checkFile*(path: string, size: BiggestInt, md5: string): bool = 
  if existsFile(path):
    let fileInfo: FileInfo = getFileInfo(path)
    if fileInfo.size == size:
      if compareMd5(path, md5):
        return true
      else:
        echo "Error: md5 did not match."
    else:
      echo "Error: file size did not match. Expected $1, got $2" % [$size, $fileInfo.size]
  else:
    return false

proc downloadRecipeList*(recipeStore, destination: string): seq[string] =
  const RecipeList = "RecipeList"
  let recpeListPckg = RecipeList & ".bz2"
  # let variablesDir = conf.getSectionValue("compile","variablesDir")
  # let destination = variablesDir / "tmp"
  # FIXME: download comppresed list only once
  if existsFile(destination / recpeListPckg):
    echo "Removing $1" % [recpeListPckg]
    removefile(recpeListPckg)
  if existsFile(destination / RecipeList):
    echo "Removing $1" % [destination / RecipeList]
    removefile(destination / RecipeList)
  discard download(recipeStore / recpeListPckg, destination)
  let cmdResult = callCommand("bunzip2", destination, [destination / recpeListPckg])
  let file = readFile(destination / RecipeList)
  return file.split("\n")
