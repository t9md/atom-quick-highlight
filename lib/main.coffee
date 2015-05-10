{CompositeDisposable, Color} = require 'atom'

module.exports =
  config:
    decorate:
      type: 'string'
      default: "highlight"
      enum: ["highlight", "box"]
      description: "How to decorate your highlight"

  # refresh:
  #   type: 'string'
  #   default: "auto"
  #   enum: ["auto", "none"]
  #   description: 'How color refreshed'

  decorations: {}
  colorIndex: -1
  colors: ['01', '02', '03', '04', '05', '06', '07', '08', '09', '10']

  activate: (state) ->
    @disposables = new CompositeDisposable
    @disposables.add atom.commands.add 'atom-workspace',
      'quick-highlight:toggle': => @toggle()
      'quick-highlight:clear':  => @clear()
      # 'quick-highlight:refresh':  => @refresh(true)

    @disposables.add atom.workspace.observeTextEditors (editor) =>
      @disposables.add editor.onDidChange @refresh.bind(@)

  deactivate: ->
    @disposables.dispose()

  serialize: ->

  toggle: ->
    return unless editor = @getEditor()
    oldCursorPosition = editor.getCursorBufferPosition()

    editor.selectWordsContainingCursors() if editor.getSelection().isEmpty()
    text = editor.getSelectedText()
    editor.getSelection().clear()

    # Check existing highlight for text
    if @decorations[editor.id]?[text]
      # Clear existing highlight and then return.
      @destroyDecorations @decorations[editor.id][text]['decorations']
      delete @decorations[editor.id][text]
      editor.setCursorBufferPosition oldCursorPosition
      return

    @highlightBuffer editor, text, @nextColor()
    editor.setCursorBufferPosition oldCursorPosition

  refresh: () ->
    return unless editor = @getEditor()
    return unless @decorations[editor.id]
    rule = @clear()
    @highlightBuffer(editor, text, color) for text, color of rule

  highlightBuffer: (editor, text, color) ->
    editor.scan ///#{@escapeRegExp(text)}///g, ({range}) =>
      @highlight(editor, text, color, range)

  highlight: (editor, text, color, range) ->
    marker = editor.markBufferRange range,
      invalidate: 'inside'
      persistent: false

    decorationPreference = atom.config.get 'quick-highlight.decorate'
    decoration = editor.decorateMarker marker,
      type: 'highlight'
      class: "quick-highlight #{decorationPreference}-#{color}"

    @decorations[editor.id] ?= {}
    @decorations[editor.id][text] ?= color: color, decorations: []
    @decorations[editor.id][text]['decorations'].push decoration

  nextColor: ->
    @colors[@colorIndex = (@colorIndex + 1) % @colors.length]

  destroyDecoration: (decoration) ->
    decoration.getMarker().destroy()

  destroyDecorations: (decorations) ->
    @destroyDecoration decoration for decoration in decorations

  # Clear all highlight and return original highlight rule
  # highlight rule is {"text": color...}
  # e.g.  {'text1': '01', 'text2': '02'}
  clear: ->
    return unless editor = @getEditor()
    rule = {}
    for own text, {color, decorations} of @decorations[editor.id]
      rule[text] = color
      @destroyDecorations decorations
    delete @decorations[editor.id]
    rule

  dump: ->
    console.log @decorations

  getEditor: ->
    atom.workspace.getActiveTextEditor()

  escapeRegExp: (string) ->
    string.replace /([.*+?^${}()|\[\]\/\\])/g, "\\$1"
