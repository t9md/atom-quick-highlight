{Range} = require 'atom'

getEditor = ->
  atom.workspace.getActiveTextEditor()

getVisibleEditor = (URI=null) ->
  (e for pane in atom.workspace.getPanes() when e = pane.getActiveEditor())

getVisibleBufferRange = (editor) ->
  [startRow, endRow] = editor.getVisibleRowRange().map (row) ->
    editor.bufferRowForScreenRow row
  new Range([startRow, 0], [endRow, Infinity])

module.exports = {
  getEditor
  getVisibleEditor
  getVisibleBufferRange
}
