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
getColorProvider = (colors) ->
  index = -1
  reset: -> index = -1
  getNext: -> colors[index = (index + 1) % colors.length]

getKeywordManager = (colorProvider) ->
  kw2color = Object.create(null)
  add:      (keyword) -> kw2color[keyword] = colorProvider.getNext()
  delete:   (keyword) -> delete kw2color[keyword]
  has:      (keyword) -> kw2color[keyword]?
  reset:    (keyword) ->
    kw2color = Object.create(null)
    colorProvider.reset()
  each:     (fn) ->
    fn(keyword, color) for keyword, color of kw2color

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
    @emitter = new Emitter
    @editors = new Map
    colorProvider = getColorProvider(['01', '02', '03', '04', '05', '06', '07', '08', '09', '10'])
    @keywords = getKeywordManager(colorProvider)

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
    {@editors, @subscriptions, @keywords} = {}

  toggle: ->
    editor = getEditor()
    point = editor.getCursorBufferPosition()
    keyword = editor.getSelectedText() or editor.getWordUnderCursor()

    if @keywords.has(keyword)
      @keywords.delete(keyword)
      @statusBarManager?.clear()
    else
      @keywords.add(keyword)
      @statusBarManager?.update @getCountForKeyword(editor, keyword)

    @refreshEditor(e) for e in getVisibleEditor()
    editor.setCursorBufferPosition point

  refreshEditor: (editor) ->
    @clearEditor editor
    @renderEditor editor

  renderEditor: (editor) ->
    decorationStyle = atom.config.get('quick-highlight.decorate')
    markerOptions = {invalidate: 'inside', persistent: false}
    scanRange = getVisibleBufferRange(editor)

    decorations = []
    @keywords.each (keyword, color) ->
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
    @keywords.reset()
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
