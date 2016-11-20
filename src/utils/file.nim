import os, osproc, strutils, strtabs, httpclient

import checkmd5
  
proc localDownloadFile*(url: string, path: string, timeout=60000): string =
  #returns the final destination
  downloadFile(url, path, timeout=90000)
  return path

proc localDownloadFile*(url: string, path: string, fileName: string, timeout=6000000): string =
  #returns the final destination
  let output = "$path/$fileName" % ["path", path,
                                    "fileName", fileName]
  downloadFile(url, output, timeout=90000)
  return output
  
proc unpackFile*(packagePath: string, targetDir: string): string =
  let unpackCommand = "tar xf $packagePath -C $targetDir" % ["packagePath", packagePath,
                                                              "targetDir", targetDir]
  return execProcess(unpackCommand)

proc checkFile*(path: string, size: BiggestInt, md5: string): bool = 
  #checks that file exists, then checks the sieze and and last checks
  #the md5
  if existsFile(path):
    let fileInfo: FileInfo = getFileInfo(path)
    echo "file info size " & $(fileInfo.size)
    echo "file size " & $size
    if fileInfo.size == size:
      if compareMd5(path, md5):
        return true
  else:
    return false
