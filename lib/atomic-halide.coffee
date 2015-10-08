# Copyright 2015 Adobe Systems Incorporated
# All Rights Reserved.

AtomicHalideView = require './atomic-halide-view'
{CompositeDisposable} = require 'atom'

module.exports = AtomicHalide =
  AtomicHalideView: null
  modalPanel: null
  subscriptions: null
  lastEditor: null
  activeEditorSub: null

  activate: (state) ->
    @AtomicHalideView = new AtomicHalideView(state.AtomicHalideViewState)
    item = @AtomicHalideView.getElement()
    @modalPanel = atom.workspace.addRightPanel(item: item, visible: false)

    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace',
      'atomic-halide:preview': => @preview()

    @subscriptions.add atom.workspace.onDidChangeActivePaneItem =>
      @updatePreview() if @modalPanel.isVisible()

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @activeEditorSub?.dispose()
    @AtomicHalideView.destroy()

  serialize: ->
    AtomicHalideViewState: @AtomicHalideView.serialize()

  observeSaves: (editor) ->
    if editor == @lastEditor
      return

    @stopObservingSaves()
    @activeEditorSub = editor.onDidSave =>
      @AtomicHalideView.refresh editor.getPath()
    @lastEditor = editor

  stopObservingSaves: ->
    if @activeEditorSub
      @activeEditorSub.dispose()
      @activeEditorSub = null
      @lastEditor = null

  updatePreview: ->
    editor = atom.workspace.getActiveTextEditor()
    if editor
      @observeSaves editor
      path = editor.getPath()
      @AtomicHalideView.refresh path if path
    else
      @stopObservingSaves()

  preview: ->
    if @modalPanel.isVisible()
      @modalPanel.hide()
      @stopObservingSaves()
    else
      @modalPanel.show()
      @updatePreview()
