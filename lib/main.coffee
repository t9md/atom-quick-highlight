{CompositeDisposable, Color} = require 'atom'

module.exports =
  config:
    decorate:
      type: 'string'
      default: "highlight"
      enum: ["highlight", "box"]
      description: "How to decorate your highlight"
  decorations: {}
  colorIndex: -1
  colors: ['01', '02', '03', '04', '05', '06', '07', '08', '09', '10']

  activate: (state) ->
    @disposables = new CompositeDisposable
    @disposables.add atom.commands.add 'atom-workspace',
      'quick-highlight:toggle': => @toggle()
      'quick-highlight:clear':  => @clear()
      'quick-highlight:dump':   => @dump()

  deactivate: ->
    @disposables.dispose()

  serialize: ->

  toggle: ->
    return unless editor = @getEditor()

    if editor.getSelection().isEmpty()
      editor.selectWordsContainingCursors()
    text = editor.getSelectedText()
    editor.getSelection().clear()

    # Check existing highlight for text
    decorations = @decorations[editor.id]?[text]
    if decorations
      # Clear existing highlight and then return.
      @destroyDecorations decorations
      delete @decorations[editor.id][text]
      return

    color = null
    editor.scan ///#{@escapeRegExp(text)}///g, ({range}) =>
      @highlight(editor, text, color ?= @nextColor(), range)

  highlight: (editor, text, color, range) ->
    marker = editor.markBufferRange range,
      invalidate: 'inside'
      persistent: false

    decorationPreference = atom.config.get 'quick-highlight.decorate'
    decoration = editor.decorateMarker marker,
      type: 'highlight'
      class: "quick-highlight #{decorationPreference}-#{color}"

    @decorations[editor.id] ?= {}
    @decorations[editor.id][text] ?= []
    @decorations[editor.id][text].push decoration

  nextColor: ->
    @colors[@colorIndex = (@colorIndex + 1) % @colors.length]

  destroyDecoration: (decoration) ->
    decoration.getMarker().destroy()

  destroyDecorations: (decorations) ->
    @destroyDecoration decoration for decoration in decorations

  clear: ->
    return unless editor = @getEditor()
    for own text, decorations of @decorations[editor.id]
      @destroyDecorations decorations
    delete @decorations[editor.id]

  dump: ->
    console.log @decorations

  getEditor: ->
    atom.workspace.getActiveTextEditor()

  escapeRegExp: (string) ->
    string.replace /([.*+?^${}()|\[\]\/\\])/g, "\\$1"
