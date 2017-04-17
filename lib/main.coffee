{CompositeDisposable, Disposable, Emitter} = require 'atom'
settings = require './settings'
QuickHighlightView = require './quick-highlight-view'
KeywordManager = require './keyword-manager'
StatusBarManager = require './status-bar-manager'

module.exports =
  config: settings.config

  activate: (state) ->
    @subscriptions = new CompositeDisposable
    @emitter = new Emitter
    @viewByEditor = new Map
    @keywordManager = new KeywordManager
    @statusBarManager = new StatusBarManager

    toggle = @toggle.bind(this)
    @subscriptions.add atom.commands.add 'atom-text-editor:not([mini])',
      'quick-highlight:toggle': -> toggle(@getModel())
      'quick-highlight:clear': => @keywordManager.clear()

    @subscriptions.add atom.workspace.observeTextEditors (editor) =>
      view = new QuickHighlightView(editor, {@keywordManager, @statusBarManager, @emitter})
      @viewByEditor.set(editor, view)

  deactivate: ->
    @keywordManager.destroy()
    @viewByEditor.forEach (view) -> view.destroy()
    @subscriptions.dispose()
    @subscriptions = null

  getCursorWord: (editor) ->
    selection = editor.getLastSelection()
    cursorPosition = selection.cursor.getBufferPosition()
    selection.selectWord()
    word = selection.getText()
    selection.cursor.setBufferPosition(cursorPosition)
    word

  toggle: (editor, keyword) ->
    keyword ?= editor.getSelectedText() or @getCursorWord(editor)
    @keywordManager.toggle(keyword)

  onDidChangeHighlight: (fn) ->
    @emitter.on('did-change-highlight', fn)

  provideQuickHighlight: ->
    onDidChangeHighlight: @onDidChangeHighlight.bind(this)

  consumeStatusBar: (statusBar) ->
    @statusBarManager.initialize(statusBar)
    @statusBarManager.attach()
    @subscriptions.add(new Disposable => @statusBarManager.detach())

  initRegistries: (Base)->
    toggle = @toggle.bind(this)
    class QuickHighlight extends Base.getClass('Operator')
      flashTarget: false
      stayAtSamePosition: true

      mutateSelection: (selection) ->
        toggle(@editor, selection.getText())

    class QuickHighlightWord extends QuickHighlight
      target: "InnerWord"

    registries = {}
    for klass in [QuickHighlight, QuickHighlightWord]
      registries[klass.name] = klass
    registries

  consumeVim: ({Base, registerCommandFromSpec}) ->
    registries = null
    getClass = (name) =>
      registries ?= @initRegistries(Base)
      registries[name]

    @subscriptions.add registerCommandFromSpec
      name: 'QuickHighlight'
      commandPrefix: 'vim-mode-plus-user'
      getClass: getClass

    @subscriptions.add registerCommandFromSpec
      name: 'QuickHighlightWord'
      commandPrefix: 'vim-mode-plus-user'
      getClass: getClass
