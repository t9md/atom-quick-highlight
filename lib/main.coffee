{CompositeDisposable, Color} = require 'atom'

# Config =
#   invalidate:
#     type: 'string'
#     default: 'inside'
#     enum: ['never', 'surround', 'overlap', 'inside', 'touch']

module.exports =
  config: Config
  decorations: {}
  colorIndex: 0
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
      delete @decoration[editor.id][text]
      return

    color = null
    editor.scan ///#{@escapeRegExp(text)}///g, ({range}) =>
      color ?= @nextColor()
      @highlight(editor, text, color, range)

  highlight: (editor, text, color, range) ->
    options =
      invalidate: 'inside'
      persistent: false

    marker = editor.markBufferRange(range, options)
    decoration = editor.decorateMarker(marker, type: 'highlight', class: "highlight-#{color}")
    @decorations[editor.id] ?= {}
    @decorations[editor.id][text] ?= []
    @decorations[editor.id][text].push decoration

  nextColor: ->
    @colorIndex = (@colorIndex + 1) % @colors.length
    @colors[@colorIndex]

  destroyDecoration: (decoration) ->
    decoration.getMarker().destroy()

  destroyDecorations: (decorations) ->
    for decoration in decorations
      @destroyDecoration decoration

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
