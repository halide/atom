# Copyright 2015 Adobe Systems Incorporated
# All Rights Reserved.

path = require 'path'
q = require 'q'
spawn = require('child_process').spawn
readFile = q.denodeify require('fs').readFile
libext = (require 'ffi').Library.EXT

runCollectingErrOutput = (cmd, includeOut, opts, args, callback) ->
  make = spawn cmd, args, opts

  outarray = []

  if includeOut
    make.stdout.on 'data', (chunk) ->
      outarray.push chunk.toString()

  make.stderr.on 'data', (chunk) ->
    outarray.push chunk.toString()

  make.on 'close', (code) ->
    callback null, code, outarray.join ''

  make.on 'error', (e) ->
    callback new Error "Unable to run make: " + e.message

if process.platform == 'win32'
  winenv = require './winenv'

  cmd = winenv.toolPath 'nmake' # 'make' on macos

  patterns = [
    "NMAKE : fatal error U1052: file 'NMakefile' not found",
    "NMAKE : fatal error U1073: don't know how to make "
  ]

  spawnBuild = (stem, libname, rootdir, callback) ->
    env = winenv.makeEnv()
    env.STEM = stem
    env.HALIDE_PATH = atom.config.get 'atomic-halide.halidePath'

    opts =
      env: env
      cwd: rootdir

    args = ["/f", "NMakefile", libname]

    runCollectingErrOutput cmd, true, opts, args, callback

  ignorableError = (code, output) ->
    for pat in patterns
      return true if output.match pat

else if process.platform == 'mac' or process.platform == 'darwin' or
    process.platform == 'linux'
  spawnBuild = (stem, libname, rootdir, callback) ->
    halidePath = atom.config.get 'atomic-halide.halidePath'
    env = { HALIDE_PATH: halidePath }

    if process.platform == 'linux'
      env.PATH = process.env.PATH
      env.LD_LIBRARY_PATH = path.join rootdir, "bin"

    opts =
      env: env
      cwd: rootdir

    args = [libname]
    runCollectingErrOutput 'make', false, opts, args, callback

  ignorableError = (code, output) ->
    code == 2 and output.match " No rule to make target "

else
  spawnBuild = (stem, libname, rootdir, callback) ->
    callback new Error "Unsupported platform: ", process.platform

module.exports.makeRenderer = (filepath, callback) ->
  rootdir = path.dirname filepath
  ext = path.extname filepath
  stem = path.basename filepath, ext

  basename = path.join 'build', stem
  libname = basename + libext

  result = q.defer()

  spawnBuild stem, libname, rootdir, result.makeNodeResolver()

  result.promise.spread (code, output) ->
    if ignorableError code, output
      throw new Error("cancel")
    else if code != 0
      err = new Error("make exited with code: " + code)
      err.output = output

      throw err
    else
      path.join rootdir, libname
