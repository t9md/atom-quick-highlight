{TextEditor, CompositeDisposable, Color} = require 'atom'

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

  toggle: ->
    return unless editor = @getActiveEditor()
    oldCursorPosition = editor.getCursorBufferPosition()

    text = @getText editor

    if @highlights[text]
      # Already exists, remove!
      @removeHighlight text
    else
      # New
      @addHighlight text, @nextColor()

    editor.setCursorBufferPosition oldCursorPosition

  addHighlight: (text, color) ->
    @highlights[text] = color
    @refreshVisibleTextEditors()

  removeHighlight: (text) ->
    delete @highlights[text]
    @refreshVisibleTextEditors()

  isActiveEditor: (editor) ->
    @getActiveEditor() is editor

  handleChanging: (editor) ->
    =>
      if @isActiveEditor editor
        @refreshVisibleTextEditors editor.getURI()

  refreshEditors: (editors) ->
    for editor in editors
      @refreshEditor editor

  refreshEditor: (editor) ->
    @clearHighlights editor
    @renderHighlights editor

  refreshVisibleTextEditors: (URI) ->
    editors = @getVisibleTextEditors()
    if URI
      editors = editors.filter (editor) -> editor.getURI() is URI
    @refreshEditors editors

  clearHighlights: (editor) ->
    if decorations = @decorations[editor.id]
      @destroyDecorations decorations
    delete @decorations[editor.id]

  renderHighlights: (editor) ->
    for text, color of @highlights
      @highlightBuffer editor, text, color

  clear: ->
    for editor in atom.workspace.getTextEditors()
      @clearHighlights editor
    @highlights = {}

  highlightBuffer: (editor, text, color) ->
    editor.scan ///#{@escapeRegExp(text)}///g, ({range}) =>
      @highlight editor, text, color, range

  highlight: (editor, text, color, range) ->
    marker = editor.markBufferRange range,
      invalidate: 'inside'
      persistent: false

    decoration = editor.decorateMarker marker,
      type: 'highlight'
      class: "quick-highlight #{@decorationPreference}-#{color}"

    @decorations[editor.id] ?= []
    @decorations[editor.id].push decoration

  nextColor: ->
    @colors[@colorIndex = (@colorIndex + 1) % @colors.length]

  destroyDecoration: (decoration) ->
    decoration.getMarker().destroy()

  destroyDecorations: (decorations) ->
    for decoration in decorations
      @destroyDecoration decoration

  getActiveEditor: ->
    atom.workspace.getActiveTextEditor()

  getVisibleTextEditors: ->
    atom.workspace.getPanes()
      .map    (pane) -> pane.getActiveEditor()
      .filter (pane) -> pane?

  getText: (editor) ->
    if editor.getSelection().isEmpty()
      editor.selectWordsContainingCursors()
    text = editor.getSelectedText()
    editor.getSelection().clear()
    text

  escapeRegExp: (string) ->
    string.replace /([.*+?^${}()|\[\]\/\\])/g, "\\$1"
