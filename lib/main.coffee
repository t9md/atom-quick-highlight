{CompositeDisposable, Emitter} = require 'atom'

KeywordManager = null

module.exports =
  activate: (state) ->
    @subscriptions = new CompositeDisposable
    @emitter = new Emitter
    @subscriptions.add atom.commands.add 'atom-text-editor:not([mini])',
      'quick-highlight:toggle': => @toggle()
      'quick-highlight:clear': => @keywordManager?.clear()

    @subscriptions.add atom.config.observe 'quick-highlight.highlightSelection', (value) =>
      if value
        @getKeywordmanager() # To initialize

  deactivate: ->
    @keywordManager?.destroy()
    @keywordManager = null
    @subscriptions.dispose()
    @subscriptions = null

  getKeywordmanager: ->
    KeywordManager ?= require './keyword-manager'
    @keywordManager ?= new KeywordManager(@emitter, @statusBar)

  toggle: (keyword) ->
    @getKeywordmanager().toggle(keyword)

  onDidChangeHighlight: (fn) ->
    @emitter.on('did-change-highlight', fn)

  provideQuickHighlight: ->
    onDidChangeHighlight: @onDidChangeHighlight.bind(this)

  consumeStatusBar: (@statusBar) ->
    if @keywordManager?
      @keywordManager.statusBarManager.initialize(@statusBar)
      @keywordManager.statusBarManager.attach()

  consumeVim: ({Base, registerCommandFromSpec}) ->
    commands = null
    getClass = (name) =>
      commands ?= require('./load-vmp-commands')(Base, @toggle.bind(this))
      commands[name]

    commandSpec = {commandPrefix: 'vim-mode-plus-user', getClass: getClass}

    @subscriptions.add(
      registerCommandFromSpec('QuickHighlight', commandSpec)
      registerCommandFromSpec('QuickHighlightWord', commandSpec)
    )
