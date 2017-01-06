{CompositeDisposable, Disposable, Emitter, Range} = require 'atom'
_ = require 'underscore-plus'
StatusBarManager = require './status-bar-manager'
settings = require './settings'
QuickHighlightView = require './quick-highlight-view'

{
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
    @viewByEditor = new Map
    @colorsByKeyword = new Map()
    @statusBarManager = new StatusBarManager

    toggle = @toggle.bind(this)
    @subscribe atom.commands.add 'atom-text-editor:not([mini])',
      'quick-highlight:toggle': -> toggle(@getModel())
      'quick-highlight:clear': => @clear()

    debouncedhighlightSelection = null
    highlightSelection = ->
    settings.observe 'highlightSelectionDelay', (delay) ->
      debouncedhighlightSelection = _.debounce(highlightSelection, delay)

    refreshEditor = @refreshEditor.bind(this)

    @subscribe atom.workspace.observeTextEditors (editor) =>
      view = new QuickHighlightView(editor, this)
      @viewByEditor.set(view, editor)

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

      # [FIXME]
      # @refreshEditor depends on editorElement.getVisibleRowRange() but it return
      # [undefined, undefined] when it called on editorElement which is not attached yet.
      # So we separately need to cover this case from Atom v1.1.0
      editorSubs.add(editorElement.onDidAttach(refresh))

      editorSubs.add editor.onDidChangeSelectionRange ({selection}) =>
        if selection.isLastSelection() and not @isLocked()
          debouncedhighlightSelection(editor)

      editorSubs.add editor.onDidDestroy =>
        # @clearEditor(editor)
        editorSubs.dispose()
        @unsubscribe(editorSubs)

      @subscribe(editorSubs)

    @subscribe atom.workspace.onDidChangeActivePaneItem (item) =>
      null
      @statusBarManager.clear()
      # if item?.getText? # Check if instance of TextEditor
      #   @refreshEditor(item)
        # @highlightSelection(item)

  subscribe: (args...) ->
    @subscriptions.add args...

  unsubscribe: (arg) ->
    @subscriptions.remove(arg)

  deactivate: ->
    @clear()
    @viewByEditor.forEach (view) ->
      view.destroy()

    @subscriptions.dispose()
    {@subscriptions} = {}

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
    if @colorsByKeyword.has(keyword)
      @colorsByKeyword.delete(keyword)
      @statusBarManager.clear()
    else
      @colorsByKeyword.set(keyword, @getNextColor())
      if settings.get('displayCountOnStatusBar')
        @statusBarManager.update(@getCountForKeyword(editor, keyword))
    @emitter.emit('did-change-keyword', {@colorsByKeyword})

  onDidChangeKeyword: (fn) -> @emitter.on('did-change-keyword', fn)

  refreshEditor: (editor) ->
    null

  clear: ->
    @colorsByKeyword.clear()
    @emitter.emit('did-change-keyword', {@colorsByKeyword})
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
