{CompositeDisposable, Disposable, Emitter, Range} = require 'atom'
_ = require 'underscore-plus'
StatusBarManager = require './status-bar-manager'
settings = require './settings'

{
  matchScope
  getVisibleEditors
  getVisibleBufferRange
  getCountForKeyword
  getCursorWord
} = require './utils'

module.exports =
  config: settings.config
  colorNumbers: ['01', '02', '03', '04', '05', '06', '07']

  activate: (state) ->
    @subscriptions = new CompositeDisposable
    @emitter = new Emitter
    @markersByEditor = new Map
    @colorByKeyword = new Map()
    @statusBarManager = new StatusBarManager

    toggle = @toggle.bind(this)
    @subscribe atom.commands.add 'atom-text-editor:not([mini])',
      'quick-highlight:toggle': -> toggle(@getModel())
      'quick-highlight:clear': => @clear()

    debouncedhighlightSelection = null
    highlightSelection = @highlightSelection.bind(this)
    settings.observe 'highlightSelectionDelay', (delay) ->
      debouncedhighlightSelection = _.debounce(highlightSelection, delay)

    refreshEditor = @refreshEditor.bind(this)

    @subscribe atom.workspace.observeTextEditors (editor) =>
      editorSubs = new CompositeDisposable
      editorSubs.add editor.onDidStopChanging ->
        if editor is atom.workspace.getActiveTextEditor()
          URI = editor.getURI()
          isChangedEditor = (editor) -> editor.getURI() is URI
          getVisibleEditors()
            .filter(isChangedEditor)
            .forEach(refreshEditor)

      editorElement = editor.element
      refresh = @refreshEditor.bind(this, editor)
      editorSubs.add(editorElement.onDidChangeScrollTop(refresh))

      # [FIXME]
      # @refreshEditor depends on editorElement.getVisibleRowRange() but it return
      # [undefined, undefined] when it called on editorElement which is not attached yet.
      # So we separately need to cover this case from Atom v1.1.0
      editorSubs.add(editorElement.onDidAttach(refresh))

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
    for marker in @selectionMarkers ? []
      marker.destroy()
    @selectionMarkers = null

  shouldExcludeEditor: (editor) ->
    editorElement = editor.element
    scopes = settings.get('highlightSelectionExcludeScopes')
    scopes.some (scope) -> matchScope(editorElement, scope)

  highlightSelection: (editor) ->
    @clearSelectionDecoration()
    return if @shouldExcludeEditor(editor)
    selection = editor.getLastSelection()
    return unless @needToHighlightSelection(selection)
    keyword = selection.getText()
    return unless scanRange = getVisibleBufferRange(editor)
    @selectionMarkers = @highlightKeyword(editor, scanRange, keyword, 'box-selection')

  needToHighlightSelection: (selection) ->
    switch
      when (not settings.get('highlightSelection'))
          , selection.isEmpty()
          , not selection.getBufferRange().isSingleLine()
          , selection.getText().length < settings.get('highlightSelectionMinimumLength')
          , /[^\S]/.test(selection.getText())
        false
      else
        true

  deactivate: ->
    @clear()
    @clearSelectionDecoration()
    @subscriptions.dispose()
    {@markersByEditor, @subscriptions} = {}

  locked: false
  isLocked: ->
    @locked

  withLock: (fn) ->
    try
      @locked = true
      value = fn()
    finally
      @locked = false
      value

  getNextColor: ->
    @colorIndex ?= -1
    @colorIndex = (@colorIndex + 1) % @colorNumbers.length
    @colorNumbers[@colorIndex]

  toggle: (editor, keyword) ->
    keyword ?= editor.getSelectedText() or @withLock(-> getCursorWord(editor))

    if @colorByKeyword.has(keyword)
      @colorByKeyword.delete(keyword)
      @statusBarManager.clear()
    else
      @colorByKeyword.set(keyword, @getNextColor())

      if settings.get('displayCountOnStatusBar')
        @statusBarManager.update(@getCountForKeyword(editor, keyword))

    for editor in getVisibleEditors()
      @refreshEditor(editor)

  refreshEditor: (editor) ->
    @clearEditor(editor)
    @renderEditor(editor)

  renderEditor: (editor) ->
    return unless scanRange = getVisibleBufferRange(editor)
    markers = []
    decorationStyle = settings.get('decorate')

    @colorByKeyword.forEach (color, keyword) =>
      colorName = "#{decorationStyle}-#{color}"
      markers = markers.concat(@highlightKeyword(editor, scanRange, keyword, colorName))
    @markersByEditor.set(editor, markers)

  highlightKeyword: (editor, scanRange, keyword, color) ->
    return [] unless editor.isAlive()

    markerOptions = {invalidate: 'inside'}
    decorationOptions = {type: 'highlight', class: "quick-highlight #{color}"}

    markers = []
    editor.scanInBufferRange ///#{_.escapeRegExp(keyword)}///g, scanRange, ({range}) ->
      marker = editor.markBufferRange(range, markerOptions)
      editor.decorateMarker(marker, decorationOptions)
      markers.push(marker)
    markers

  clearEditor: (editor) ->
    if markers = @markersByEditor.get(editor)
      for marker in markers
        marker.destroy()
      @markersByEditor.delete(editor)

  clear: ->
    @markersByEditor.forEach (markers) ->
      for marker in markers
        marker.destroy()
    @markersByEditor.clear()
    @colorByKeyword.clear()
    @colorIndex = null

    @statusBarManager.clear()

  getCountForKeyword: (editor, keyword) ->
    getCountForKeyword(editor, keyword)

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
      stayAtSamePosition: true

      mutateSelection: (selection) ->
        toggle(@editor, selection.getText())

    @subscribe(QuickHighlight.registerCommand())
