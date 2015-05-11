{CompositeDisposable, Color} = require 'atom'

module.exports =
  config:
    decorate:
      type: 'string'
      default: "highlight"
      enum: ["highlight", "box"]
      description: "How to decorate your highlight"

  # refresh:
  #   type: 'string'
  #   default: "auto"
  #   enum: ["auto", "none"]
  #   description: 'How color refreshed'

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
      # 'quick-highlight:refresh':  => @refresh(true)

    @disposables.add atom.workspace.observeTextEditors (editor) =>
      @disposables.add editor.onDidStopChanging @handleChanging(editor).bind(@)

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
      # New one.
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
    handler = ->
      if @isActiveEditor(editor)
        @refreshVisibleTextEditors(editor.getURI())
    handler

  refreshEditors: (editors) ->
    @refreshEditor editor for editor in editors

  refreshEditor: (editor) ->
    @clearHighlights editor
    @renderHighlights editor

  refreshVisibleTextEditors: (URI) ->
    editors = @getVisibleTextEditors()
    if URI
      editors = (editor for editor in editors when editor.getURI() is URI)
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

  # renderHighlightsVisibleRange: (editor) ->
  #   [start, end] = editor.getVisibleRowRange()
  #   range = [[start, 0], [end, 0]]
  #   for text, color of @highlights
  #     @highlightBufferRange editor, text, color, range

  # highlightBufferRange: (editor, text, color, range) ->
  #   editor.scanInBufferRange ///#{@escapeRegExp(text)}///g, range, ({range}) =>
  #     @highlight editor, text, color, range

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
    @destroyDecoration decoration for decoration in decorations

  dump: ->
    console.log @decorations

  getActiveEditor: ->
    atom.workspace.getActiveTextEditor()

  getVisibleTextEditors: ->
    panes = atom.workspace.getPanes()
    (pane.getActiveEditor() for pane in panes when pane.getActiveEditor())

  getText: (editor) ->
    if editor.getSelection().isEmpty()
      editor.selectWordsContainingCursors()
    text = editor.getSelectedText()
    editor.getSelection().clear()
    text

  escapeRegExp: (string) ->
    string.replace /([.*+?^${}()|\[\]\/\\])/g, "\\$1"
