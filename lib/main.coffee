{CompositeDisposable, Disposable, Emitter, Range} = require 'atom'
_ = require 'underscore-plus'
StatusBarManager = require './status-bar-manager'

allWhiteSpaceRegExp = /^\s*$/

Config =
  decorate:
    order: 1
    type: 'string'
    default: 'box'
    enum: ['box', 'highlight']
    description: "Decoation style for highlight"
  highlightSelection:
    order: 5
    type: 'boolean'
    default: true
  highlightSelectionMinimumLength:
    order: 6
    type: 'integer'
    default: 2
    description: "Minimum length of selection to be highlight"
  highlightSelectionExcludeScopes:
    order: 7
    type: 'array'
    items:
      type: 'string'
    default: [
      'vim-mode-plus.visual-mode.blockwise',
    ]
  highlightSelectionDelay:
    order: 8
    type: 'integer'
    default: 100
    description: "Delay(ms) before start to highlight selection when selection changed"
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
class KeywordManager
  colors: ['01', '02', '03', '04', '05', '06', '07']
  index: null
  constructor: ->
    @reset()
  add: (keyword) ->
    @index = (@index + 1) % @colors.length
    @kw2color[keyword] = @colors[@index]
  delete: (keyword) ->
    delete @kw2color[keyword]
  has: (keyword) ->
    keyword of @kw2color
  reset: (keyword) ->
    @kw2color = Object.create(null)
    @index = -1
  each: (fn) ->
    fn(keyword, color) for keyword, color of @kw2color

getEditor = ->
  atom.workspace.getActiveTextEditor()

getView = (model) ->
  atom.views.getView(model)

getVisibleEditors = ->
  (editor for pane in atom.workspace.getPanes() when editor = pane.getActiveEditor())

getConfig = (name) ->
  atom.config.get("quick-highlight.#{name}")

observeConfig = (name, fn) ->
  atom.config.observe("quick-highlight.#{name}", fn)

getVisibleBufferRange = (editor) ->
  editorElement = getView(editor)
  unless visibleRowRange = editorElement.getVisibleRowRange()
    # When editorElement.component is not yet available it return null
    # Hope this guard fix issue https://github.com/t9md/atom-quick-highlight/issues/7
    return null

  [startRow, endRow] = visibleRowRange.map (row) ->
    editor.bufferRowForScreenRow(row)

  # FIXME: editorElement.getVisibleRowRange() return [NaN, NaN] when
  # it called to editorElement still not yet attached.
  return null if (isNaN(startRow) or isNaN(endRow))
  new Range([startRow, 0], [endRow, Infinity])

module.exports =
  config: Config

  activate: (state) ->
    @subscriptions = new CompositeDisposable
    @emitter = new Emitter
    @decorationsByEditor = new Map
    @keywords = new KeywordManager()
    @statusBarManager = new StatusBarManager

    @subscribe atom.commands.add 'atom-text-editor',
      'quick-highlight:toggle': => @toggle()
      'quick-highlight:clear': => @clear()

    debouncedhighlightSelection = null
    observeConfig 'highlightSelectionDelay', (delay) =>
      debouncedhighlightSelection = _.debounce(@highlightSelection.bind(this), delay)

    @subscribe atom.workspace.observeTextEditors (editor) =>
      editorSubs = new CompositeDisposable
      editorSubs.add editor.onDidStopChanging =>
        return unless getEditor() is editor
        URI = editor.getURI()
        @refreshEditor(e) for e in getVisibleEditors() when (e.getURI() is URI)

      editorElement = getView(editor)
      editorSubs.add(editorElement.onDidChangeScrollTop => @refreshEditor(editor))

      # [FIXME]
      # @refreshEditor depend on editorElement.getVisibleRowRange() but it return
      # [undefined, undefined] when it called on editorElement not attached yet.
      # So we separately need to cover this case from Atom v1.1.0
      editorSubs.add(editorElement.onDidAttach => @refreshEditor(editor))

      editorSubs.add editor.onDidChangeSelectionRange ({selection}) =>
        if selection.isLastSelection() and not @isLocked()
          debouncedhighlightSelection(editor)
      editorSubs.add(editorElement.onDidChangeScrollTop => @highlightSelection(editor))

      editorSubs.add editor.onDidDestroy =>
        @clearEditor(editor)
        editorSubs.dispose()
        @unsubscribe(editorSubs)

      @subscribe(editorSubs)

    @subscribe atom.workspace.onDidChangeActivePaneItem (item) =>
      @statusBarManager.clear()
      if item?.getText? # Check if instance of TextEditor
        @refreshEditor(item)
        @highlightSelection(item)

  subscribe: (args...) ->
    @subscriptions.add args...

  unsubscribe: (arg) ->
    @subscriptions.remove(arg)

  clearSelectionDecoration: ->
    d.getMarker().destroy() for d in @selectionDecorations ? []
    @selectionDecorations = null

  shouldExcludeEditor: (editor) ->
    editorElement = getView(editor)
    scopes = getConfig('highlightSelectionExcludeScopes')
    classes = scopes.map (scope) -> scope.split('.')

    for classNames in classes
      containsCount = 0
      for className in classNames
        containsCount += 1 if editorElement.classList.contains(className)
      return true if containsCount is classNames.length
    false

  highlightSelection: (editor) ->
    @clearSelectionDecoration()
    return if @shouldExcludeEditor(editor)
    selection = editor.getLastSelection()
    return unless @needToHighlightSelection(selection)
    keyword = selection.getText()
    return unless scanRange = getVisibleBufferRange(editor)
    @selectionDecorations = @highlightKeyword(editor, scanRange, keyword, 'box-selection')

  needToHighlightSelection: (selection) ->
    switch
      when (not getConfig('highlightSelection'))
          , selection.isEmpty()
          , not selection.getBufferRange().isSingleLine()
          , selection.getText().length < getConfig('highlightSelectionMinimumLength')
          , allWhiteSpaceRegExp.test(selection.getText())
        false
      else
        true

  deactivate: ->
    @clear()
    @clearSelectionDecoration()
    @subscriptions.dispose()
    {@decorationsByEditor, @subscriptions, @keywords} = {}

  locked: false
  isLocked: ->
    @locked

  withLock: (fn) ->
    try
      @locked = true
      fn()
    finally
      @locked = false

  getKeywordUnderCursor: ->
    editor = getEditor()
    selection = editor.getLastSelection()
    {cursor} = selection
    point = cursor.getBufferPosition()
    if selection.isEmpty()
      @withLock -> selection.selectWord()

    word = selection.getText()
    unless cursor.getBufferPosition().isEqual(point)
      @withLock -> cursor.setBufferPosition(point)
    word

  toggle: (keyword) ->
    keyword ?= @getKeywordUnderCursor()
    editor = getEditor()
    if @keywords.has(keyword)
      @keywords.delete(keyword)
      @statusBarManager.clear()
    else
      @keywords.add(keyword)
      if getConfig('displayCountOnStatusBar')
        @statusBarManager.update(@getCountForKeyword(editor, keyword))
    @refreshEditor(editor) for editor in getVisibleEditors()

  refreshEditor: (editor) ->
    @clearEditor(editor)
    @renderEditor(editor)

  renderEditor: (editor) ->
    return unless scanRange = getVisibleBufferRange(editor)
    decorations = []
    decorationStyle = getConfig('decorate')
    @keywords.each (keyword, color) =>
      color = "#{decorationStyle}-#{color}"
      decorations = decorations.concat @highlightKeyword(editor, scanRange, keyword, color)
    @decorationsByEditor.set(editor, decorations)

  highlightKeyword: (editor, scanRange, keyword, color) ->
    return [] unless editor.isAlive()
    classNames = "quick-highlight #{color}"
    pattern = ///#{_.escapeRegExp(keyword)}///g
    decorations = []
    editor.scanInBufferRange pattern, scanRange, ({range}) =>
      decorations.push(@decorateRange(editor, range, {classNames}))
    decorations

  clearEditor: (editor) ->
    if @decorationsByEditor.has(editor)
      d.getMarker().destroy() for d in @decorationsByEditor.get(editor)
      @decorationsByEditor.delete(editor)

  clear: ->
    @decorationsByEditor.forEach (decorations, editor) =>
      @clearEditor(editor)
    @decorationsByEditor.clear()
    @keywords.reset()
    @statusBarManager.clear()

  decorateRange: (editor, range, {classNames}) ->
    marker = editor.markBufferRange(range, invalidate: 'inside')
    editor.decorateMarker(marker, {type: 'highlight', class: classNames})

  getCountForKeyword: (editor, keyword) ->
    count = 0
    editor.scan(///#{_.escapeRegExp(keyword)}///g, -> count++)
    count

  consumeStatusBar: (statusBar) ->
    @statusBarManager.initialize(statusBar)
    @statusBarManager.attach()
    @subscriptions.add new Disposable =>
      @statusBarManager.detach()
      @statusBarManager = null

  consumeVim: ({Base}) ->
    toggle = @toggle.bind(this)
    class QuickHighlight extends Base.getClass('Operator')
      @commandPrefix: 'vim-mode-plus-user'
      flashTarget: false
      keepCursorPosition: true

      mutateSelection: (selection) ->
        toggle(selection.getText())
        @restorePoint(selection)

    @subscribe(QuickHighlight.registerCommand())
