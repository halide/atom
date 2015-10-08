# Copyright 2015 Adobe Systems Incorporated
# All Rights Reserved.

path = require 'path'

vcInstallDir = "C:\\Program Files (x86)\\Microsoft Visual Studio 12.0\\VC"
kitsDir = "C:\\Program Files (x86)\\Windows Kits\\8.1"

INCLUDE = [
  (path.join vcInstallDir, "INCLUDE"),
  (path.join vcInstallDir, "ATLMFC", "INCLUDE"),
  (path.join kitsDir, "include", "shared"),
  (path.join kitsDir, "include", "um")
]

LIBPATH = [
  (path.join vcInstallDir, "LIB"),
  (path.join vcInstallDir, "ATLMFC", "LIB")
]

LIB = [
  (path.join vcInstallDir, "LIB"),
  (path.join vcInstallDir, "ATLMFC", "LIB"),
  (path.join kitsDir, "lib", "winv6.3", "um", "x86")
]

binPath = path.join vcInstallDir, "BIN"

Path = [
  binPath,
  process.env.Path
]

module.exports.makeEnv = () ->
  INCLUDE: INCLUDE.join ";"
  LIBPATH: LIBPATH.join ";"
  LIB: LIB.join ";"
  Path: Path.join ";"

module.exports.toolPath = (basename) ->
  path.join vcInstallDir, "BIN", basename
