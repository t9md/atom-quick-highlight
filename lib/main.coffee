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

module.exports =
  config: settings.config

  activate: (state) ->
    @subscriptions = new CompositeDisposable
    @emitter = new Emitter
    @decorationsByEditor = new Map
    @keywords = new KeywordManager()
    @statusBarManager = new StatusBarManager

    toggle = @toggle.bind(this)
    @subscribe atom.commands.add 'atom-text-editor:not([mini])',
      'quick-highlight:toggle': -> toggle(@getModel())
      'quick-highlight:clear': => @clear()

    debouncedhighlightSelection = null
    settings.observe 'highlightSelectionDelay', (delay) =>
      debouncedhighlightSelection = _.debounce(@highlightSelection.bind(this), delay)

    @subscribe atom.workspace.observeTextEditors (editor) =>
      editorSubs = new CompositeDisposable
      editorSubs.add editor.onDidStopChanging =>
        return unless atom.workspace.getActiveTextEditor() is editor
        URI = editor.getURI()
        for e in getVisibleEditors() when (e.getURI() is URI)
          @refreshEditor(e)

      editorElement = editor.element
      editorSubs.add(editor.element.onDidChangeScrollTop => @refreshEditor(editor))

      # [FIXME]
      # @refreshEditor depends on editorElement.getVisibleRowRange() but it return
      # [undefined, undefined] when it called on editorElement which is not attached yet.
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
    scopes = settings.get('highlightSelectionExcludeScopes')
    scopes.some (scope) ->
      matchScope(editor.element, scope)

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
    {@decorationsByEditor, @subscriptions, @keywords} = {}

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

  toggle: (editor, keyword) ->
    keyword ?= editor.getSelectedText() or @withLock(-> getCursorWord(editor))
    if @keywords.has(keyword)
      @keywords.delete(keyword)
      @statusBarManager.clear()
    else
      @keywords.add(keyword)
      if settings.get('displayCountOnStatusBar')
        @statusBarManager.update(@getCountForKeyword(editor, keyword))
    @refreshEditor(editor) for editor in getVisibleEditors()

  refreshEditor: (editor) ->
    @clearEditor(editor)
    @renderEditor(editor)

  renderEditor: (editor) ->
    return unless scanRange = getVisibleBufferRange(editor)
    decorations = []
    decorationStyle = settings.get('decorate')
    @keywords.each (keyword, color) =>
      color = "#{decorationStyle}-#{color}"
      decorations = decorations.concat(@highlightKeyword(editor, scanRange, keyword, color))
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
