# Copyright 2015 Adobe Systems Incorporated
# All Rights Reserved.

{TextEditor} = require 'atom'

dialog = require('electron').remote.dialog

path = require 'path'
url = require 'url'

binder = require './halide-lib-binder'
{makeRenderer} = require './halide-make-renderer'

width = 600
height = 600
channels = 3

panelMargin = 10

getImageData = (url, willWait, callback) ->
  canvas = document.createElement('canvas')
  context = canvas.getContext('2d')
  imageObj = new Image()
  loaded = false

  imageObj.onload = ->
    console.log "loaded callback invoked"
    loaded = true
    iowidth = Math.min(imageObj.width, width)
    ioheight = Math.min(imageObj.height, height)

    canvas.setAttribute('width', iowidth)
    canvas.setAttribute('height', ioheight)
    context.drawImage(imageObj, 0, 0)
    data = context.getImageData(0, 0, iowidth, ioheight)
    callback( data )

  imageObj.src = url

  setTimeout ->
    willWait() if not loaded
  , 100

makeBufferProcessor = (ctx) ->
  id = ctx.createImageData width, height

  (buf) ->
    if not buf
      ctx.clearRect 0, 0, width, height
      return

    data = id.data

    plane = width * height
    for ch in [0..2]
      base = ch * plane
      pos = 0
      for i in [ch..data.length] by 4
        data[i] = buf[base + pos]
        pos += 1

    for i in [3..data.length] by 4
      data[i] = 255

    ctx.putImageData( id, 0, 0 )

makeSetter = (obj, key) ->
  (value) ->
    if obj[key] != value
      obj[key] = value
      return true
    return false

urlsByName = { }

module.exports =
class AtomicHalideView
  subscriptions: null
  paramsList: null
  errorOutput: null
  rendererBinding: null
  resizeListener: null
  processBuffer: null
  showFPS: null
  building: false
  waiting: null

  constructor: (serializedState) ->
    @rendererBinding = new binder.LibBinder
    @rendererBinding.prepare width, height, channels

    # Create root element
    @element = document.createElement('div')
    @element.classList.add('atomic-halide')

    configure = document.createElement('button')
    configure.classList.add('btn')
    configure.appendChild(document.createTextNode "Configure")
    configure.style.margin = '10px'
    configure.onclick = => @configurePressed()

    @element.appendChild configure

    canvas = document.createElement('canvas')
    canvas.setAttribute('width', width)
    canvas.setAttribute('height', height)
    cdiv = document.createElement('div')
    cdiv.appendChild(canvas)

    ctx = canvas.getContext '2d'
    @processBuffer = makeBufferProcessor ctx
    @showMessage = (message) ->
      ctx.font = 'italic 20pt Arial'
      ctx.fillStyle = 'white'
      ctx.textBaseline = 'top'
      ctx.fillText message, 40, 40

    @element.appendChild(cdiv)
    @resizeListener = => @updatePanelHeight()
    window.addEventListener 'resize', @resizeListener

  configurePressed: ->
    paths = dialog.showOpenDialog
      title: "Choose Halide Folder"
      properties: ['openDirectory']

    if paths
      console.log "Chose halide directory: ", paths[0]
      atom.config.set 'atomic-halide.halidePath', paths[0]

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    window.removeEventListener 'resize', @resizeListener
    @resizeListener = null
    @element.remove()
    @renderLibrary?.close()

  getElement: ->
    @element

  makeSlider: (min, max, digits, def, setter) ->
    row = document.createElement('div')

    valueDisplay = document.createElement('div')
    valueDisplay.style.float = 'right'
    valueDisplay.style.fontSize = 'small'
    updateValue = (value) ->
      valueDisplay.innerHTML = "" + value.toFixed(digits)

    updateValue(def)

    slider = document.createElement('input')
    slider.type = "range"
    slider.min = min
    slider.max = max
    slider.step = Math.pow(10, -digits)
    slider.value = def

    slider.oninput = =>
      newValue = parseFloat(slider.value)
      if setter newValue
        updateValue newValue
        @reloadImage()

    setter def

    slider.style.height = '12px'
    slider.style.width = (width - 80) + 'px'
    slider.style.float = 'left'

    row.appendChild slider
    row.appendChild valueDisplay

    row

  makeCheckbox: (def, setter) ->
    row = document.createElement('div')

    checkbox = document.createElement('input')
    checkbox.type = "checkbox"
    checkbox.checked = def

    checkbox.onchange = =>
      newValue = checkbox.checked
      setter newValue
      @reloadImage()

    setter def

    row.appendChild checkbox

    row

  makeTextField: (def, twidth, handler ) ->
    input = document.createElement 'atom-text-editor'
    input.style.width = twidth + 'px'

    editor  = input.getModel()

    editor.setText(def)
    editor.setMini(true)

    editor.onDidStopChanging ->
      handler(editor.getText())

    input

  makeBufferInputRow: (arg, setter, defaultDir) ->
    input = arg.makeBuffer width, height, channels
    name = arg.name

    willWait = =>
      input.fillWithCheckerboard 16
      @reloadImage()

    updateUrl = (url) =>
      urlsByName[name] = url
      getImageData url, willWait, (sourceImage) =>
        input.fillWithImage sourceImage
        @reloadImage()

    setter input.ref()
    imageUrl = @chooseInputUrl name, defaultDir
    row = document.createElement 'div'
    urlInput = @makeTextField imageUrl, width - 80, updateUrl
    urlInput.style.float = 'left'

    choose = document.createElement('button')
    choose.classList.add('btn')
    choose.appendChild(document.createTextNode "...")
    choose.style.float = 'right'
    choose.onclick = ->
      paths = dialog.showOpenDialog
        title: "Choose Input Image"
        properties: ['openFile']

      if paths
        newUrl = url.format
          pathname: paths[0]
          protocol: "file"
          slashes: true

        urlInput.getModel().setText(newUrl)
        updateUrl newUrl

    row.appendChild urlInput
    row.appendChild choose

    updateUrl imageUrl

    row

  makeTextInputRow: (arg, setter) ->
    setter arg.default
    row = document.createElement 'div'

    field = @makeTextField "" + arg.default, width - panelMargin, (value) =>
      if setter value
        @reloadImage()

    row.appendChild field

    row

  chooseInputUrl: (name, defaultDir) ->
    urlsByName[name] or @makeInputUrl name + ".jpg", defaultDir

  makeInputUrl: (basename, defaultDir) ->
    url.format
      pathname: path.join defaultDir, basename
      protocol: "file"
      slashes: true

  reloadImage: ->
    start = window.performance.now()
    [outbuf, errors] = @rendererBinding.call()
    @processBuffer outbuf
    if outbuf
      delta = window.performance.now() - start
      @showMessage "FPS: " + Math.round(1000 / delta)
      @clearError()
    else
      @showMessage "Error reported from rendering."

      @reportError errors

  clearError: ->
    if @errorOutput
      @element.removeChild @errorOutput
      @errorOutput = null

  reportError: (message) ->
    if @errorOutput
      @clearError()

    @errorOutput = document.createElement 'div'
    @errorOutput.appendChild document.createTextNode message
    @errorOutput.style.backgroundColor = '#660000'
    @element.insertBefore @errorOutput, @paramsList
    @updatePanelHeight()

  updatePanelHeight: () ->
    if @paramsList
      total = @element.parentElement.getBoundingClientRect().height
      for e in @element.childNodes
        total -= e.getBoundingClientRect().height if e != @paramsList

      @paramsList.style.height = (total - panelMargin * 2) + 'px'

  replaceParamsPanel: (newPanel) ->
    @clearError()
    if @paramsList
      @element.removeChild(@paramsList)

    newPanel.style.overflow = 'auto'

    @paramsList = newPanel
    @updatePanelHeight()
    @element.appendChild(newPanel)

  handleNewLibrary: (vars, args, defaultDir) ->
    newPanel = document.createElement 'div'
    newPanel.style.margin = panelMargin + 'px'

    for arg in vars
      setter = makeSetter args, arg.name

      if arg.buffer
        row = @makeBufferInputRow arg, setter, defaultDir
      else if arg.bool
        row = @makeCheckbox arg.default, setter
      else
        if arg.min != null and arg.max != null
          min = arg.min
          max = arg.max
          if arg.int
            digits = 0 # round to the nearest int value
          else
            # for floats, use a number of decimal points based on the range
            # between min and max (large ranges get fewer, small get more)
            digits = Math.ceil(Math.max(0, Math.log10(1 / (max - min)) + 3))

          row = @makeSlider min, max, digits, arg.default, setter
        else
          row = @makeTextInputRow arg, setter

      newPanel.appendChild(document.createTextNode arg.name)
      newPanel.appendChild(row)

      clearer = document.createElement 'div'
      clearer.style.clear = 'both'

      newPanel.appendChild clearer
      newPanel.appendChild document.createElement 'br'

    newPanel

  handleError: (err) ->
    if err.message == "cancel"
      return
    else if err instanceof TypeError
      throw err

    message = "Error making renderer: " + err.message

    newPanel = document.createElement 'div'
    newPanel.appendChild( document.createTextNode message )
    if err.output
      outdiv = document.createElement('div')
      pretag = document.createElement('pre')
      pretag.classList.add('error-output')
      pretag.style.width = width + 'px'
      pretag.appendChild document.createTextNode err.output
      outdiv.appendChild pretag

      newPanel.appendChild outdiv

    newPanel

  listParams: (srcpath) ->
    if @building
      @waiting = srcpath
      return

    @building = true

    # The binding must be closed to rebuild on Windows so that
    # the attempt to overwrite the DLL doesn't hit a file lock
    if process.platform == 'win32'
      @rendererBinding.close()

    args = { }

    makeRenderer srcpath
      .then (libpath) =>
        @rendererBinding.bind("render", libpath, args)
      .then (vars) =>
        newPanel = @handleNewLibrary vars, args, path.dirname srcpath
        @reloadImage()
        newPanel
      .catch (e) => @handleError(e)
      .then (newPanel) =>
        @replaceParamsPanel(newPanel) if newPanel
      .finally =>
        @building = false

        if @waiting
          nextPath = @waiting
          @waiting = null
          setImmediate => @listParams nextPath
      .done()

  refresh: (path) ->
    @listParams path
