{CompositeDisposable, Emitter} = require 'atom'
module.exports =
  activate: (state) ->
    @subscriptions = new CompositeDisposable
    @emitter = new Emitter
    @subscriptions.add atom.commands.add 'atom-text-editor:not([mini])',
      'quick-highlight:toggle': => @toggle()
      'quick-highlight:clear': => @keywordManager?.clear()

    @subscriptions.add atom.config.observe 'quick-highlight.highlightSelection', (value) =>
      if value
        @initQuickHighlightIfNeeded()

  deactivate: ->
    @keywordManager?.destroy()
    @keywordManager = null

    if @viewByEditor?
      @viewByEditor.forEach (view) -> view.destroy()
      @viewByEditor.clear()
      @viewByEditor = null

    @subscriptions.dispose()
    @subscriptions = null

    @editorSubscription?.dispose()
    @editorSubscription = null

    @statusBarManager?.detach()
    @statusBarManager = null

  getCursorWord: (editor) ->
    selection = editor.getLastSelection()
    cursorPosition = selection.cursor.getBufferPosition()
    selection.selectWord()
    word = selection.getText()
    selection.cursor.setBufferPosition(cursorPosition)
    word

  initQuickHighlightIfNeeded: ->
    return if @editorSubscription?

    QuickHighlightView = require './quick-highlight-view'
    KeywordManager = require './keyword-manager'
    StatusBarManager = require './status-bar-manager'

    @viewByEditor = new Map
    @keywordManager = new KeywordManager
    @statusBarManager = new StatusBarManager
    if @statusBar?
      @statusBarManager.initialize(@statusBar)
      @statusBarManager.attach()

    @editorSubscription = atom.workspace.observeTextEditors (editor) =>
      options = {@keywordManager, @statusBarManager, @emitter}
      @viewByEditor.set(editor, new QuickHighlightView(editor, options))

  toggle: (keyword) ->
    editor = atom.workspace.getActiveTextEditor()
    keyword ?= editor.getSelectedText() or @getCursorWord(editor)
    @initQuickHighlightIfNeeded()
    @keywordManager.toggle(keyword)

  onDidChangeHighlight: (fn) ->
    @emitter.on('did-change-highlight', fn)

  provideQuickHighlight: ->
    onDidChangeHighlight: @onDidChangeHighlight.bind(this)

  consumeStatusBar: (@statusBar) ->
    if @statusBarManager?
      @statusBarManager.initialize(@statusBar)
      @statusBarManager.attach()

  initVimClassRegistry: (Base) ->
    toggle = @toggle.bind(this)
    class QuickHighlight extends Base.getClass('Operator')
      flashTarget: false
      stayAtSamePosition: true

      mutateSelection: (selection) ->
        toggle(selection.getText())

    class QuickHighlightWord extends QuickHighlight
      target: "InnerWord"

    return {QuickHighlight, QuickHighlightWord}

  consumeVim: ({Base, registerCommandFromSpec}) ->
    classes = null
    commandSpec =
      commandPrefix: 'vim-mode-plus-user'
      getClass: (name) =>
        classes ?= @initVimClassRegistry(Base)
        classes[name]

    @subscriptions.add(
      registerCommandFromSpec('QuickHighlight', commandSpec)
      registerCommandFromSpec('QuickHighlightWord', commandSpec)
    )
