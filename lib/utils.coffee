getVisibleEditors = ->
  atom.workspace.getPanes()
    .map (pane) -> pane.getActiveEditor()
    .filter (editor) -> editor?

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
  matchScope
  getVisibleEditors
  getVisibleBufferRange
  getCursorWord
}
