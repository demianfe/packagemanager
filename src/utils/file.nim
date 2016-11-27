import os, osproc, strutils, strtabs, httpclient, checkmd5, streams

proc which*(command: string): string =
  #finds the command in path
  for dir in getEnv("PATH").split(":"):
    if dir.contains("bin"):
      for commandPath in walkDir(dir):
        if commandPath.path.contains(command):
          let pathParts = commandPath.path.split("/")
          if pathParts[len(pathParts) - 1] == command:
            return commandPath.path

proc callCommand*(command:string, workingDir: string = "", args: openArray[string] = []): int =
  #convient way to call startProcess and handle output
  let options: set[ProcessOption] = {poUsePath, poStdErrToStdOut}
  var p = startProcess(command=command,
                         workingDir=workingDir,
                         args=args,
                         options=options)
  var
    pStdout = p.outputStream()
    line: TaintedString = ""
  while p.peekExitCode == -1:
    if readLine(pStdout, line):
      echo line
  echo "Exiting with code $1" % $p.peekExitCode
  p.close
  return p.peekExitCode
  
proc download(url, destination: string): int =
  let command = which "wget"
  return callCommand(command=command, workingDir=destination, args=[url])

#depreacte
proc localDownloadFile*(url, path: string, timeout=6000000): string {.deprecated.} =
  echo "downloading $1" % [url]
  echo download(url, path)
  #downloadFile(url, output, timeout=90000)
  return path

proc localDownloadFile*(url, path, filename: string, timeout=6000000): string {.deprecated.}=
  echo "Downloading $1 into $2" % [url, path]
  discard download(url, path)
  #downloadFile(url, output, timeout=90000)
  return path / filename
  
proc unpackFile*(packagePath, targetDir: string): int =
  let
    command = which "tar"
    options: set[ProcessOption] = {poUsePath, poStdErrToStdOut}
    args = @["xf", packagePath, "-C", "targetDir"]
  let p = startProcess(command)
  waitForExit(p, 90000)
  #return execProcess(unpackCommand)

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
