{CompositeDisposable, Emitter} = require 'atom'
QuickHighlightView = null
KeywordManager = null
StatusBarManager = null

CONFIG =
  decorate:
    order: 0
    type: 'string'
    default: 'underline'
    enum: ['underline', 'box', 'highlight']
    description: "Decoation style for highlight"
  highlightSelection:
    order: 1
    type: 'boolean'
    default: true
    description: """
    [Require Restart]<br>
    This value is checked on startup.<br>
    When disabled quick-highlight delay startup IO( files to load by require ) for faster activation<br>
    """
  highlightSelectionMinimumLength:
    order: 2
    type: 'integer'
    default: 2
    minimum: 1
    description: "Minimum length of selection to be highlight"
  highlightSelectionExcludeScopes:
    order: 3
    default: ['vim-mode-plus.visual-mode.blockwise']
    type: 'array'
    items:
      type: 'string'
  highlightSelectionDelay:
    order: 4
    type: 'integer'
    default: 100
    description: "Delay(ms) before start to highlight selection when selection changed"
  displayCountOnStatusBar:
    order: 5
    type: 'boolean'
    default: true
    description: "Show found count on StatusBar"
  countDisplayPosition:
    order: 6
    type: 'string'
    default: 'Left'
    enum: ['Left', 'Right']
  countDisplayPriority:
    order: 7
    type: 'integer'
    default: 120
    description: "Lower priority get closer position to the edges of the window"
  countDisplayStyles:
    order: 8
    type: 'string'
    default: 'badge icon icon-location'
    description: "Style class for count span element. See `styleguide:show`."

module.exports =
  config: CONFIG

  activate: (state) ->
    @subscriptions = new CompositeDisposable
    @emitter = new Emitter
    @viewByEditor = new Map
    toggle = @toggle.bind(this)
    @subscriptions.add atom.commands.add 'atom-text-editor:not([mini])',
      'quick-highlight:toggle': -> toggle(@getModel())
      'quick-highlight:clear': => @keywordManager?.clear()

    if atom.config.get('quick-highlight.highlightSelection')
      @editorSubscription = @observeTextEditors()

  deactivate: ->
    @keywordManager?.destroy()
    @viewByEditor.forEach (view) -> view.destroy()
    @subscriptions.dispose()
    @editorSubscription?.dispose()
    @statusBarManager.detach()
    [@keywordManager, @subscriptions] = []

  getCursorWord: (editor) ->
    selection = editor.getLastSelection()
    cursorPosition = selection.cursor.getBufferPosition()
    selection.selectWord()
    word = selection.getText()
    selection.cursor.setBufferPosition(cursorPosition)
    word

  observeTextEditors: ->
    QuickHighlightView ?= require './quick-highlight-view'
    KeywordManager ?= require './keyword-manager'
    StatusBarManager ?= require './status-bar-manager'

    @keywordManager = new KeywordManager
    @statusBarManager = new StatusBarManager
    if @statusBar?
      @statusBarManager.initialize(@statusBar)
      @statusBarManager.attach()

    atom.workspace.observeTextEditors (editor) =>
      options = {
        editor: editor
        keywordManager: @keywordManager
        statusBarManager: @statusBarManager
        emitter: @emitter
      }
      view = new QuickHighlightView(editor, options)
      @viewByEditor.set(editor, view)

  toggle: (editor, keyword) ->
    keyword ?= editor.getSelectedText() or @getCursorWord(editor)
    @editorSubscription ?= @observeTextEditors()
    @keywordManager.toggle(keyword)

  onDidChangeHighlight: (fn) ->
    @emitter.on('did-change-highlight', fn)

  provideQuickHighlight: ->
    onDidChangeHighlight: @onDidChangeHighlight.bind(this)

  consumeStatusBar: (@statusBar) ->
    if @statusBarManager?
      @statusBarManager.initialize(@statusBar)
      @statusBarManager.attach()

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

    commandPrefix = 'vim-mode-plus-user'
    spec = {commandPrefix, getClass}

    @subscriptions.add(
      registerCommandFromSpec('QuickHighlight', spec),
      registerCommandFromSpec('QuickHighlightWord', spec)
    )
