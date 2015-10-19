{TextEditor, CompositeDisposable, Disposable, Emitter} = require 'atom'
_ = require 'underscore-plus'
{getEditor, getVisibleEditor, getVisibleBufferRange} = require './utils'
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

  # @highlights keep keyword to colorName pair.
  # e.g.
  #   @highlights =
  #     text1: 'highlight-01'
  #     text2: 'highlight-02'
  highlights: null

  colorIndex: -1
  colors: ['01', '02', '03', '04', '05', '06', '07', '08', '09', '10']

  activate: (state) ->
    @editorSubscriptions = {}
    @subscriptions = subs = new CompositeDisposable
    @emitter = new Emitter
    @editors = new Map

    if atom.config.get 'quick-highlight.displayCountOnStatusBar'
      @statusBarManager = new StatusBarManager

    subs.add atom.commands.add 'atom-text-editor',
      'quick-highlight:toggle': => @toggle()
      'quick-highlight:clear':  => @clear()

    subs.add atom.config.observe 'quick-highlight.decorate', (value) =>
      @decorationPreference = value

    subs.add atom.workspace.observeTextEditors (editor) =>
      subs.add editor.onDidStopChanging =>
        return unless getEditor() is editor
        URI = editor.getURI()
        @refreshEditor(e) for e in getVisibleEditor() when (e.getURI() is URI)

      subs.add editor.onDidChangeScrollTop => @refreshEditor(editor)
      subs.add editor.onDidChangeScrollLeft => @refreshEditor(editor)

      subs.add me = editor.onDidDestroy ->
        @clearHighlights(editor)
        me.dispose()
        subs.remove(me)

    subs.add atom.workspace.onDidChangeActivePaneItem (item) =>
      @statusBarManager?.clear()
      if item instanceof TextEditor
        @refreshEditor item

  getNextColor: ->
    @colorIndex = (@colorIndex + 1) % @colors.length
    @colors[@colorIndex]

  deactivate: ->
    @clear()
    @subscriptions.dispose()
    @subscriptions = null

  toggle: ->
    editor = getEditor()
    point = editor.getCursorBufferPosition()
    keyword = editor.getSelectedText() or editor.getWordUnderCursor()

    @highlights ?= Object.create(null)
    if @highlights[keyword]?
      delete @highlights[keyword]
      @statusBarManager?.clear()
    else
      @highlights[keyword] = @getNextColor()
      @statusBarManager?.update @getCount(editor, keyword)

    for editor in getVisibleEditor()
      @refreshEditor editor
    editor.setCursorBufferPosition point

  clear: ->
    @editors.forEach (decorations, editor) =>
      @destroyDecorations decorations
    @highlights  = null
    @colorIndex  = -1
    @statusBarManager?.clear()

  refreshEditor: (editor) ->
    @clearHighlights editor
    @renderHighlights editor

  renderHighlights: (editor) ->
    for keyword, color of @highlights
      @highlightEditor editor, keyword, color

  clearHighlights: (editor) ->
    if decorations = @editors.get(editor)
      @destroyDecorations decorations
      @editors.delete(editor)

  getCount: (editor, keyword) ->
    pattern = ///#{_.escapeRegExp(keyword)}///g
    count = 0
    editor.scan pattern, ({range}) ->
      count++
    count

  highlightEditor: (editor, keyword, color) ->
    pattern = ///#{_.escapeRegExp(keyword)}///g
    scanRange = getVisibleBufferRange(editor)
    decorations = []
    editor.scanInBufferRange pattern, scanRange, ({range}) =>
      decorations.push @decorate(editor, range, color)

    if decorations
      if @editors.has(editor)
        decorations = @editors.get(editor).concat(decorations)
      @editors.set(editor, decorations)

  decorate: (editor, range, color) ->
    marker = editor.markBufferRange range,
      invalidate: 'inside'
      persistent: false

    editor.decorateMarker marker,
      type: 'highlight'
      class: "quick-highlight #{@decorationPreference}-#{color}"

  destroyDecorations: (decorations) ->
    for decoration in decorations
      decoration.getMarker().destroy()

  consumeStatusBar: (statusBar) ->
    return unless @statusBarManager?
    @statusBarManager.initialize(statusBar)
    @statusBarManager.attach()
    @subscriptions.add new Disposable =>
      @statusBarManager.detach()
