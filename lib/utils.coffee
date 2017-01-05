_ = require 'underscore-plus'
{Range} = require 'atom'

getVisibleEditors = ->
  atom.workspace.getPanes()
    .map (pane) -> pane.getActiveEditor()
    .filter (editor) -> editor?

getVisibleBufferRange = (editor) ->
  editorElement = editor.element
  unless visibleRowRange = editorElement.getVisibleRowRange()
    # When editorElement.component is not yet available it return null
    # Hope this guard fix issue https://github.com/t9md/atom-quick-highlight/issues/7
    return null

  [startRow, endRow] = visibleRowRange.map (row) ->
    editor.bufferRowForScreenRow(row)

  # FIXME: editorElement.getVisibleRowRange() return [NaN, NaN] when
  # it called to editorElement still not yet attached.
  return null if (isNaN(startRow) or isNaN(endRow))
  new Range([startRow, 0], [endRow, Infinity])

getCursorWord = (editor) ->
  selection = editor.getLastSelection()
  {cursor} = selection
  cursorPosition = cursor.getBufferPosition()
  selection.selectWord()
  word = selection.getText()
  cursor.setBufferPosition(cursorPosition)
  word

getCountForKeyword = (editor, keyword) ->
  count = 0
  editor.scan(///#{_.escapeRegExp(keyword)}///g, -> count++)
  count

matchScope = (editorElement, scope) ->
  containsCount = 0
  classNames = scope.split('.')
  for className in classNames
    containsCount += 1 if editorElement.classList.contains(className)

  containsCount is classNames.length

module.exports = {
  matchScope
  getVisibleEditors
  getVisibleBufferRange
  getCountForKeyword
  getCursorWord
}
