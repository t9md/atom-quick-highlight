{CompositeDisposable, Disposable, Emitter, Range} = require 'atom'
_ = require 'underscore-plus'
settings = require './settings'
QuickHighlightView = require './quick-highlight-view'
KeywordManager = require './keyword-manager'
StatusBarManager = require './status-bar-manager'

{
  getCursorWord
} = require './utils'

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
      view = new QuickHighlightView(editor, {@keywordManager, @statusBarManager})
      @viewByEditor.set(editor, view)

  deactivate: ->
    @keywordManager.destroy()
    @viewByEditor.forEach (view) -> view.destroy()
    @subscriptions.dispose()
    @subscriptions = null

  toggle: (editor, keyword) ->
    keyword ?= editor.getSelectedText() or getCursorWord(editor)
    @keywordManager.toggle(keyword)

  consumeStatusBar: (statusBar) ->
    @statusBarManager.initialize(statusBar)
    @statusBarManager.attach()
    @subscriptions.add(new Disposable => @statusBarManager.detach())

  consumeVim: ({Base}) ->
    toggle = @toggle.bind(this)
    class QuickHighlight extends Base.getClass('Operator')
      @commandPrefix: 'vim-mode-plus-user'
      flashTarget: false
      stayAtSamePosition: true

      mutateSelection: (selection) ->
        toggle(@editor, selection.getText())

    class QuickHighlightWord extends QuickHighlight
      target: "InnerWord"

    @subscriptions.add(
      QuickHighlight.registerCommand()
      QuickHighlightWord.registerCommand()
    )
