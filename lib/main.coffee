{TextEditor, CompositeDisposable, Disposable} = require 'atom'
_ = require 'underscore-plus'
StatusBarManager = require './status-bar-manager'

Config =
  decorate:
    order: 1
    type: 'string'
    default: 'box'
    enum: ['box', 'highlight']
    description: "How to decorate your highlight"
  displayCountOnStatusBar:
    order: 11
    type: 'boolean'
    default: true
    description: "Show found count on StatusBar on highlight"
  countDisplayPosition:
    order: 12
    type: 'string'
    default: 'Left'
    enum: ['Left', 'Right']
  countDisplayPriority:
    order: 13
    type: 'integer'
    default: 120
    description: "Lower priority get closer position to the edges of the window"
  countDisplayStyles:
    order: 14
    type: 'string'
    default: 'badge icon icon-location'
    description: "Style class for count span element. See `styleguide:show`."

module.exports =
  config: Config
  subscriptions: null
  editorSubscriptions: null
  statusBarManager: null

  # Keep list of decoration for each editor.
  # Used for bulk destroy().
  decorations: null

  # @highlights keep keyword to colorName pair.
  # e.g.
  #   @highlights =
  #     text1: 'highlight-01'
  #     text2: 'highlight-02'
  highlights: null

  colorIndex: null
  colors: ['01', '02', '03', '04', '05', '06', '07', '08', '09', '10']

  activate: (state) ->
    @editorSubscriptions = {}
    @subscriptions = new CompositeDisposable
    if atom.config.get 'quick-highlight.displayCountOnStatusBar'
      @statusBarManager = new StatusBarManager

    @subscriptions.add atom.commands.add 'atom-workspace',
      'quick-highlight:toggle': => @toggle()
      'quick-highlight:clear':  => @clear()

    @subscriptions.add @observeTextEditors()
    @subscriptions.add @onDidChangeActivePaneItem()

    @decorationPreference = atom.config.get 'quick-highlight.decorate'
    @subscriptions.add atom.config.onDidChange 'quick-highlight.decorate', ({newValue}) =>
      @decorationPreference = newValue
    @decorations = {}

  onDidChangeActivePaneItem: ->
    atom.workspace.onDidChangeActivePaneItem (item) =>
      @statusBarManager?.update()
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
        @statusBarManager?.update()
        for _editor in @getVisibleEditor(editor.getURI())
          @refreshEditor _editor

    atom.workspace.observeTextEditors (editor) =>
      @editorSubscriptions[editor.id] = new CompositeDisposable
      @editorSubscriptions[editor.id].add onDidStopChanging(editor)
      @editorSubscriptions[editor.id].add onDidDestroy(editor)

  deactivate: ->
    @clear()
    for editorID, subscriptions of @editorSubscriptions
      subscriptions.dispose()
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
    count = null

    @decorations ?= {}
    @highlights ?= Object.create(null)
    if @highlights[text]
      @removeHighlight text
    else
      @addHighlight text, @getNextColor()
      if @statusBarManager?
        count = @decorations[editor.id][text].length

    @statusBarManager?.update count

    # Restore original cursor position
    editor.setCursorBufferPosition oldCursorPosition

  clear: ->
    for editorID of @decorations
      @clearHighlights editorID
    @highlights  = null
    @decorations = null
    @colorIndex  = null
    @statusBarManager?.update()

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
    return unless @decorations
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

    @decorations[editor.id] ?= Object.create(null)
    @decorations[editor.id][text] ?= []
    @decorations[editor.id][text].push decoration

  destroyDecorations: (decorations) ->
    for decoration in decorations
      decoration.getMarker().destroy()

  getNextColor: ->
    @colorIndex ?= -1
    @colors[@colorIndex = (@colorIndex + 1) % @colors.length]

  consumeStatusBar: (statusBar) ->
    return unless @statusBarManager?
    @statusBarManager.initialize(statusBar)
    @statusBarManager.attach()
    @subscriptions.add new Disposable =>
      @statusBarManager.detach()
