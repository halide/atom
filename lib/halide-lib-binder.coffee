# Copyright 2015 Adobe Systems Incorporated
# All Rights Reserved.

ffi = require 'ffi'
DLFLAGS = ffi.DynamicLibrary.FLAGS
ref = require 'ref'
struct = require 'ref-struct'
ArrayType = require 'ref-array'

HalideBuffer = struct
  dev: 'uint64',
  host: ref.refType('uint8')
  extent: ArrayType('uint32', 4)
  stride: ArrayType('uint32', 4)
  min: ArrayType('uint32', 4)
  elem_size: 'uint32'
  #only used by GPU, but may need special alignment tweaks
  host_dirty: 'bool'
  dev_dirty: 'bool'

HalideFilterArgument = struct
  name: 'string'
  kind: 'int32'
  dimensions: 'int32'
  type_code: 'int32'
  type_bits: 'int32'
  def: ref.refType('void')
  min: ref.refType('void')
  max: ref.refType('void')

HalideFilterMetadata = struct
  version: 'int32'
  num_arguments: 'int32'
  arguments: ArrayType(HalideFilterArgument)
  target: ref.refType('string')
  name: ref.refType('string')

type_code_names = ["int", "uint", "float", "handle"]
kind_names = ["scalar", "input", "output"]

buffer_ptr = ref.refType(HalideBuffer)

makeBuffer = (width, height, channels) ->
  hbuf = new HalideBuffer()
  nbuf = new Buffer(width * height * channels)

  hbuf.dev = 0
  hbuf.elem_size = 1
  hbuf.host = nbuf
  hbuf.min[0] = 0
  hbuf.min[1] = 0
  hbuf.min[2] = 0
  hbuf.min[3] = 0
  hbuf.extent[0] = width
  hbuf.extent[1] = height
  hbuf.extent[2] = channels
  hbuf.extent[3] = 0
  hbuf.stride[0] = 1
  hbuf.stride[1] = width
  hbuf.stride[2] = width * height
  hbuf.stride[3] = 0

  [ hbuf, nbuf ]

class InputBuffer
  buffer: null
  array: null

  constructor: (width, height, channels) ->
    [@buffer, @array] = makeBuffer width, height, channels

  ref: ->
    @buffer.ref()

  width: ->
    @buffer.stride[1]

  plane: ->
    @buffer.stride[2]

  fillWithCheckerboard: (size) ->
    width = @width()
    array = @array
    plane = @plane()

    limit = Math.min(width * size * 2, plane)
    for i in [0..limit - 1]
      y = i % width
      x = (i - y) / width
      if (Math.floor (x / size) % 2) != (Math.floor (y / size) % 2)
        array[i] = 64
      else
        array[i] = 192

    # copy it to fill the channel plane
    for i in [limit..plane - 1]
      array[i] = array[i - limit]

    # make the other two planes match
    for i in [plane..array.length - 1]
      array[i] = array[i - plane]

  fillWithImage: (sourceImage) ->
    width = @width()
    array = @array
    plane = @plane()

    srcdata = sourceImage.data
    stride = sourceImage.width
    x = 0
    y = 0

    for i in [0..srcdata.length - 1]
      ch = i % 4
      if ch != 3
        array[plane * ch + x * width + y] = srcdata[i]
      else
        y += 1
        if y == stride
          y = 0
          x += 1

makeInputBuffer = (args...) ->
  new InputBuffer args...

endianQualifier = ref.endianness

makeDereferencer = (type, bits) ->
  if bits == 1
    return (buf) ->
      if buf.isNull()
        null
      else
        buf.reinterpret(1).readInt8() != 0
  else if type == "int" && bits == 8
    reader = "readInt8"
  else if type == "uint" && bits == 8
    reader = "readUInt8"
  else if type == "int" && bits % 8 == 0
    reader = "readInt" + bits + endianQualifier
  else if type == "uint" && bits % 8 == 0
    reader = "readUInt" + bits + endianQualifier
  else if type == "float" && bits == 32
    reader = "readFloat" + endianQualifier
  else if type == "float" && bits == 64
    reader = "readDouble" + endianQualifier
  else
    throw new Error("invalid type: " + type + " " + bits)

  (buf) ->
    if buf.isNull()
      null
    else
      buf.reinterpret(bits/8)[reader]()

convertArgumentStruct = (ma) ->
  type = type_code_names[ma.type_code]

  name: ma.name
  dimensions: ma.dimensions
  kind: kind_names[ma.kind]
  type: type
  bits: ma.type_bits
  is_int: type == "uint" || type == "int"

gatherParams = (args, nargs) ->
  params = []
  outputs = 0

  for i in [0..nargs - 1]
    ma = convertArgumentStruct args[i]

    supported_buffer = ma.dimensions == 3 && ma.is_int && ma.bits == 8

    if ma.type == "handle"
      if i != 0
        throw new Error("Unexpected handle at position other than 0: " + i)

      params.push ref.refType(ref.types.void)
    else if ma.kind == "output" && supported_buffer
      params.push buffer_ptr
      outputs += 1
    else if ma.kind == "input" && supported_buffer
      params.push buffer_ptr
    else if ma.kind == "scalar"
      if ma.type == "float" && ma.bits == 32
        params.push "float"
      else if ma.type == "float" && ma.bits == 64
        params.push "double"
      else if ma.type == "uint" && ma.bits == 1
        params.push "bool"
      else if ma.is_int && ma.bits > 0 && ma.bits % 8 == 0
        params.push ma.type + ma.bits
      else
        throw new Error("Unhandled type: " + ma.type + ma.bits)
    else
      throw new Error("Unhandled kind: " + ma.kind + " type: " + ma.type +
        " with " + ma.bits +  " bits and " + ma.dimensions + " dimensions")

  if outputs != 1
    throw new Error("Expected exactly one output, got: " + outputs )

  params

gatherVars = (args, nargs) ->
  vars = []

  for i in [0..nargs - 1]
    ma = convertArgumentStruct args[i]

    if ma.kind == "input"
      vars.push
        name: ma.name
        makeBuffer: makeInputBuffer
        buffer: true
    else if ma.kind == "scalar" and ma.type != "handle"
      dereffer = makeDereferencer ma.type, ma.bits

      vars.push
        int: ma.is_int
        bool: ma.bits == 1
        name: ma.name
        default: dereffer args[i].def
        min: dereffer args[i].min
        max: dereffer args[i].max

  vars

module.exports.LibBinder =
class LibBinder
  renderLibrary: null
  renderFunction: null
  output: null
  outbuf: null

  close: ->
    if @renderLibrary
      @renderLibrary.close()
      @renderLibrary = null
      @renderFunction = null

  call: ->
    if @renderFunction
      @renderFunction()
    else
      [null, "No currently bound function."]

  prepare: (width, height, channels) ->
    [@output, @outbuf] = makeBuffer width, height, channels

  bind: (fnname, libpath, args) ->
    @close()

    @renderLibrary = ffi.DynamicLibrary( libpath, DLFLAGS.RTLD_NOW )
    rawfn = @renderLibrary.get fnname

    struct = @renderLibrary.get fnname + "_metadata"
    struct = struct.reinterpret(HalideFilterMetadata.size)
    metadata = new HalideFilterMetadata(struct)

    if metadata.version != 0
      throw new Error "Unknown Filter Metadata version: " + metadata.version

    metadata.arguments.length = metadata.num_arguments

    params = gatherParams metadata.arguments, metadata.num_arguments
    vars = gatherVars metadata.arguments, metadata.num_arguments

    boundfn = ffi.ForeignFunction rawfn, 'int', params

    errorBuffer = new Buffer(4096)
    wasError = true

    @renderFunction = ->
      if wasError
        errorBuffer.fill '\0'

      result = [errorBuffer]
      for arg in vars
        result.push args[arg.name]
      result.push @output.ref()

      code = boundfn result...
      wasError = code != 0

      if code == 0
        [@outbuf, errorBuffer]
      else
        [null, errorBuffer]

    return vars
