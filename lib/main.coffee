{TextEditor, CompositeDisposable, Disposable, Emitter, Range} = require 'atom'
_ = require 'underscore-plus'
StatusBarManager = require './status-bar-manager'

Config =
  decorate:
    order: 1
    type: 'string'
    default: 'box'
    enum: ['box', 'highlight']
    description: "Decoation style for highlight"
  displayCountOnStatusBar:
    order: 11
    type: 'boolean'
    default: true
    description: "Show found count on StatusBar"
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

# Utils
# -------------------------
getEditor = ->
  atom.workspace.getActiveTextEditor()

getVisibleEditor = ->
  (e for p in atom.workspace.getPanes() when e = p.getActiveEditor())

getVisibleBufferRange = (editor) ->
  [startRow, endRow] = editor.getVisibleRowRange().map (row) ->
    editor.bufferRowForScreenRow row
  new Range([startRow, 0], [endRow, Infinity])

module.exports =
  config: Config

  activate: (state) ->
    @subscriptions = subs = new CompositeDisposable
    @colorIndex = -1
    @colors = ['01', '02', '03', '04', '05', '06', '07', '08', '09', '10']
    @emitter = new Emitter
    @editors = new Map

    if atom.config.get 'quick-highlight.displayCountOnStatusBar'
      @statusBarManager = new StatusBarManager

    subs.add atom.commands.add 'atom-text-editor',
      'quick-highlight:toggle': => @toggle()
      'quick-highlight:clear':  => @clear()

    subs.add atom.workspace.observeTextEditors (editor) =>
      editorSubs = new CompositeDisposable
      editorSubs.add editor.onDidStopChanging =>
        return unless getEditor() is editor
        URI = editor.getURI()
        @refreshEditor(e) for e in getVisibleEditor() when (e.getURI() is URI)

      editorSubs.add editor.onDidChangeScrollTop => @refreshEditor(editor)
      editorSubs.add editor.onDidChangeScrollLeft => @refreshEditor(editor)

      editorSubs.add editor.onDidDestroy =>
        @clearEditor editor
        editorSubs.dispose()
        subs.remove(editorSubs)
        
      subs.add editorSubs

    subs.add atom.workspace.onDidChangeActivePaneItem (item) =>
      @statusBarManager?.clear()
      @refreshEditor(item) if item instanceof TextEditor

  deactivate: ->
    @clear()
    @subscriptions.dispose()
    {@editors, @subscriptions, keyword2color, @colorIndex} = {}

  toggle: ->
    editor = getEditor()
    point = editor.getCursorBufferPosition()
    keyword = editor.getSelectedText() or editor.getWordUnderCursor()

    @keyword2color ?= Object.create(null)
    if @keyword2color[keyword]?
      delete @keyword2color[keyword]
      @statusBarManager?.clear()
    else
      @colorIndex = (@colorIndex + 1) % @colors.length
      @keyword2color[keyword] = @colors[@colorIndex]
      @statusBarManager?.update @getCountForKeyword(editor, keyword)

    @refreshEditor(e) for e in getVisibleEditor()
    editor.setCursorBufferPosition point

  refreshEditor: (editor) ->
    @clearEditor editor
    @renderEditor editor

  renderEditor: (editor) ->
    decorationStyle = atom.config.get('quick-highlight.decorate')
    scanRange = getVisibleBufferRange(editor)
    markerOptions = {invalidate: 'inside', persistent: false}

    decorations = []
    for keyword, color of @keyword2color
      klass = "quick-highlight #{decorationStyle}-#{color}"
      decorationOptions = {type: 'highlight', class: klass}

      pattern = ///#{_.escapeRegExp(keyword)}///g
      editor.scanInBufferRange pattern, scanRange, ({range}) ->
        marker = editor.markBufferRange range, markerOptions
        decorations.push editor.decorateMarker marker, decorationOptions
    @editors.set(editor, decorations)

  clearEditor: (editor) ->
    if decorations = @editors.get(editor)
      d.getMarker().destroy() for d in decorations
      @editors.delete(editor)

  clear: ->
    @editors.forEach (decorations, editor) =>
      @clearEditor editor
    @editors.clear()
    @keyword2color  = null
    @colorIndex  = -1
    @statusBarManager?.clear()

  getCountForKeyword: (editor, keyword) ->
    count = 0
    editor.scan ///#{_.escapeRegExp(keyword)}///g, -> count++
    count

  consumeStatusBar: (statusBar) ->
    return unless @statusBarManager?
    @statusBarManager.initialize(statusBar)
    @statusBarManager.attach()
    @subscriptions.add new Disposable =>
      @statusBarManager.detach()
      @statusBarManager = null
