{Emitter} = require 'atom'
QuickHighlightView = require './quick-highlight-view'
StatusBarManager = require './status-bar-manager'

module.exports =
class KeywordManager
  colorNumbers: ['01', '02', '03', '04', '05', '06', '07']
  latestKeyword: null

  onDidChangeKeyword: (fn) -> @emitter.on('did-change-keyword', fn)
  emitDidChangeKeyword: -> @emitter.emit('did-change-keyword')

  onDidClearKeyword: (fn) -> @emitter.on('did-clear-keyword', fn)
  emitDidClearKeyword: -> @emitter.emit('did-clear-keyword')

  constructor: (mainEmitter, statusBar) ->
    @emitter = new Emitter
    @viewByEditor = new Map
    @statusBarManager = new StatusBarManager
    @reset()

    if statusBar?
      @statusBarManager.initialize(statusBar)
      @statusBarManager.attach()

    @editorSubscription = atom.workspace.observeTextEditors (editor) =>
      options =
        keywordManager: this
        statusBarManager: @statusBarManager
        emitter: mainEmitter
      @viewByEditor.set(editor, new QuickHighlightView(editor, options))

  reset: ->
    @keywordToColor = Object.create(null)
    @colorIndex = -1

  getCursorWord: (editor) ->
    selection = editor.getLastSelection()
    cursorPosition = selection.cursor.getBufferPosition()
    selection.selectWord()
    word = selection.getText()
    selection.cursor.setBufferPosition(cursorPosition)
    word

  toggle: (keyword) ->
    unless keyword?
      editor = atom.workspace.getActiveTextEditor()
      keyword = editor.getSelectedText() or @getCursorWord(editor)

    if keyword of @keywordToColor
      delete @keywordToColor[keyword]
    else
      @keywordToColor[keyword] = @getNextColor()
      @latestKeyword = keyword
    @emitDidChangeKeyword()

  clear: ->
    @reset()
    @emitDidClearKeyword()

  getNextColor: ->
    @colorIndex = (@colorIndex + 1) % @colorNumbers.length
    @colorNumbers[@colorIndex]

  destroy: ->
    if @viewByEditor?
      @viewByEditor.forEach (view) -> view.destroy()
      @viewByEditor.clear()
      @viewByEditor = null

    @editorSubscription?.dispose()
    @editorSubscription = null

    @statusBarManager?.detach()
    @statusBarManager = null
