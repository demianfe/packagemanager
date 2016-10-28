import md5
import os

proc calculateMD5Incremental(filename: string) : string =
  # "borrowed" from http://forum.nim-lang.org/t/716  
  const blockSize: int = 8192
  var
    c: MD5Context
    d: MD5Digest
    f: File
    bytesRead: int = 0
    buffer: array[blockSize, char]
    byteTotal: int = 0
  
  #read chunk of file, calling update until all bytes have been read
  try:
    f = open(filename)
    
    md5Init(c)
    bytesRead = f.readBuffer(buffer.addr, blockSize)
    
    while bytesRead > 0:
      byteTotal += bytesRead
      md5Update(c, buffer, bytesRead)
      bytesRead = f.readBuffer(buffer.addr, blockSize)
    
    md5Final(c, d)
  
  except IOError:
    echo("File not found.")
  finally:
    if f != nil:
      close(f)
  
  result = $d

proc compareMd5*(filename: string, md5:string): bool =
  #calculates the md5 from the file name and compares it with md5 parameter
  return calculateMD5Incremental(filename) == md5
