_ = require 'underscore-plus'

getVisibleEditors = ->
  atom.workspace.getPanes()
    .map (pane) -> pane.getActiveEditor()
    .filter (editor) -> editor?

collectKeywordRanges = (editor, keyword) ->
  pattern = ///#{_.escapeRegExp(keyword)}///g
  ranges = []
  editor.scan pattern, ({range}) ->
    ranges.push(range)
  ranges

getCursorWord = (editor) ->
  selection = editor.getLastSelection()
  {cursor} = selection
  cursorPosition = cursor.getBufferPosition()
  selection.selectWord()
  word = selection.getText()
  cursor.setBufferPosition(cursorPosition)
  word

matchScope = (editorElement, scope) ->
  containsCount = 0
  classNames = scope.split('.')
  for className in classNames
    containsCount += 1 if editorElement.classList.contains(className)

  containsCount is classNames.length

module.exports = {
  collectKeywordRanges
  matchScope
  getVisibleEditors
  getCursorWord
}
