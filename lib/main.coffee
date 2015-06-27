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
  subscriptions: null
  editorSubscriptions: null

  # Keep list of decoration for each editor.
  # Used for bulk destroy().
  decorations: {}

  # @highlights keep keyword to colorName pair.
  # e.g.
  #   @highlights =
  #     text1: 'highlight-01'
  #     text2: 'highlight-02'
  highlights: {}

  colorIndex: null
  colors: ['01', '02', '03', '04', '05', '06', '07', '08', '09', '10']

  activate: (state) ->
    @editorSubscriptions = {}
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace',
      'quick-highlight:toggle': => @toggle()
      'quick-highlight:clear':  => @clear()

    @subscriptions.add @observeTextEditors()
    @subscriptions.add @onDidChangeActivePaneItem()

    @decorationPreference = atom.config.get 'quick-highlight.decorate'
    @subscriptions.add atom.config.onDidChange 'quick-highlight.decorate', ({newValue}) =>
      @decorationPreference = newValue

  onDidChangeActivePaneItem: ->
    atom.workspace.onDidChangeActivePaneItem (item) =>
      if item instanceof TextEditor
        @refreshEditor item

  observeTextEditors: ->
    onDidDestroy = (editor) =>
      editor.onDidDestroy =>
        @clearHighlights editor
        @editorSubscriptions[editor.id]?.dispose()
        delete @editorSubscriptions[editor.id]

    onDidStopChanging = (editor) =>
      editor.onDidStopChanging =>
        return unless editor is @getEditor() # is ActiveEditor?
        for _editor in @getVisibleEditor(editor.getURI())
          @refreshEditor _editor

    atom.workspace.observeTextEditors (editor) =>
      @editorSubscriptions[editor.id] = new CompositeDisposable
      @editorSubscriptions[editor.id].add onDidStopChanging(editor)
      @editorSubscriptions[editor.id].add onDidDestroy(editor)

  deactivate: ->
    @clear()
    for editorID, disposables of @editorSubscriptions
      disposables.dispose()
    @editorSubscriptions = null
    @subscriptions.dispose()
    @subscriptions = null

  getEditor: ->
    atom.workspace.getActiveTextEditor()

  getVisibleEditor: (URI) ->
    editors = atom.workspace.getPanes()
      .map    (pane)   -> pane.getActiveEditor()
      .filter (editor) -> editor?

    if URI
      editors = editors.filter (editor) ->
        editor.getURI() is URI
    editors

  toggle: ->
    return unless editor = @getEditor()

    # Save original cursor position.
    oldCursorPosition = editor.getCursorBufferPosition()

    text = editor.getSelectedText() or editor.getWordUnderCursor()
    if @highlights[text]
      @removeHighlight text
    else
      @addHighlight text, @getNextColor()

    # Restore original cursor position
    editor.setCursorBufferPosition oldCursorPosition

  clear: ->
    for editorID of @decorations
      @clearHighlights editorID
    @highlights = {}
    @decorations = {}
    @colorIndex = null

  addHighlight: (text, color) ->
    for editor in @getVisibleEditor()
      @highlightEditor editor, text, color
    @highlights[text] = color

  removeHighlight: (text) ->
    for editor in @getVisibleEditor()
      if decorations = @decorations[editor.id]?[text]
        @destroyDecorations decorations
        delete @decorations[editor.id][text]
    delete @highlights[text]

  refreshEditor: (editor) ->
    @clearHighlights editor
    @renderHighlights editor

  renderHighlights: (editor) ->
    for text, color of @highlights
      @highlightEditor editor, text, color

  # editor is TextEditor or TextEditor's ID.
  clearHighlights: (editor) ->
    editorID = if (editor instanceof TextEditor) then editor.id else editor
    if text2decorations = @decorations[editorID]
      for text, decorations of text2decorations
        @destroyDecorations decorations
    delete @decorations[editor.id]

  highlightEditor: (editor, text, color) ->
    editor.scan ///#{_.escapeRegExp(text)}///g, ({range}) =>
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
      decoration.getMarker().destroy()

  getNextColor: ->
    @colorIndex ?= -1
    @colors[@colorIndex = (@colorIndex + 1) % @colors.length]
