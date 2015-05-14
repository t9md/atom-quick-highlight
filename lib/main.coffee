{TextEditor, CompositeDisposable} = require 'atom'
_ = require 'underscore-plus'

Config =
  decorate:
    type: 'string'
    default: 'box'
    enum: ['box', 'highlight']
    description: "How to decorate your highlight"

module.exports =
  config: Config

  # Keep list of decoration for each editor.
  # Used for bulk destroy().
  decorations: {}

  # @highlights keep keyword to colorName pair.
  # e.g.
  #   @highlights =
  #     text1: 'highlight-01'
  #     text2: 'highlight-02'
  highlights: {}

  colorIndex: -1
  colors: ['01', '02', '03', '04', '05', '06', '07', '08', '09', '10']

  activate: (state) ->
    @disposables = new CompositeDisposable
    @disposables.add atom.commands.add 'atom-workspace',
      'quick-highlight:toggle': => @toggle()
      'quick-highlight:clear':  => @clear()

    @disposables.add atom.workspace.observeTextEditors (editor) =>
      @disposables.add editor.onDidStopChanging @handleChanging(editor)

    @disposables.add atom.workspace.onDidChangeActivePaneItem (item) =>
      if item instanceof TextEditor
        @refreshEditor item

    @decorationPreference = atom.config.get 'quick-highlight.decorate'
    @disposables.add atom.config.onDidChange 'quick-highlight.decorate', ({newValue}) =>
      @decorationPreference = newValue

  deactivate: ->
    @disposables.dispose()

  serialize: ->

  getActiveEditor: ->
    atom.workspace.getActiveTextEditor()

  isActiveEditor: (editor) ->
    @getActiveEditor() is editor

  getVisibleTextEditors: (URI) ->
    editors = atom.workspace.getPanes()
      .map    (pane)   -> pane.getActiveEditor()
      .filter (editor) -> editor?

    if URI
      editors = editors.filter (editor) -> editor.getURI() is URI
    editors

  handleChanging: (editor) ->
    =>
      if @isActiveEditor editor
        @refreshEditors @getVisibleTextEditors(editor.getURI())

  toggle: ->
    return unless editor = @getActiveEditor()

    # Save original cursor position.
    oldCursorPosition = editor.getCursorBufferPosition()

    text = @getText editor
    if @highlights[text]
      @removeHighlight text
    else
      @addHighlight text, @nextColor()

    # Restore original cursor position
    editor.setCursorBufferPosition oldCursorPosition

  clear: ->
    for editor in atom.workspace.getTextEditors()
      @clearHighlights editor
    @highlights = {}
    @decorations = {}

  addHighlight: (text, color) ->
    for editor in @getVisibleTextEditors()
      @highlightEditor editor, text, color
    @highlights[text] = color

  removeHighlight: (text) ->
    for editor in @getVisibleTextEditors()
      if decorations = @decorations[editor.id]?[text]
        @destroyDecorations decorations
        delete @decorations[editor.id][text]
    delete @highlights[text]

  refreshEditors: (editors) ->
    @refreshEditor editor for editor in editors

  refreshEditor: (editor) ->
    @clearHighlights editor
    @renderHighlights editor

  renderHighlights: (editor) ->
    for text, color of @highlights
      @highlightEditor editor, text, color

  clearHighlights: (editor) ->
    if decorations = @decorations[editor.id]
      @destroyDecorations _.chain(decorations).values().flatten().value()
    delete @decorations[editor.id]

  highlightEditor: (editor, text, color) ->
    editor.scan ///#{@escapeRegExp(text)}///g, ({range}) =>
      @highlight editor, text, color, range

  highlight: (editor, text, color, range) ->
    marker = editor.markBufferRange range,
      invalidate: 'inside'
      persistent: false

    decoration = editor.decorateMarker marker,
      type: 'highlight'
      class: "quick-highlight #{@decorationPreference}-#{color}"

    @decorations[editor.id] ?= {}
    @decorations[editor.id][text] ?= []
    @decorations[editor.id][text].push decoration

  destroyDecorations: (decorations) ->
    for decoration in decorations
      @destroyDecoration decoration

  destroyDecoration: (decoration) ->
    decoration.getMarker().destroy()

  nextColor: ->
    @colors[@colorIndex = (@colorIndex + 1) % @colors.length]

  ###
  Section: Utility methods
  ###

  getText: (editor) ->
    if editor.getSelection().isEmpty()
      editor.selectWordsContainingCursors()
    text = editor.getSelectedText()
    editor.getSelection().clear()
    text

  escapeRegExp: (string) ->
    string.replace /([.*+?^${}()|\[\]\/\\])/g, "\\$1"
