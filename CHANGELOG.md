## 0.4.0
- Add operator command for vim-mode-plus, `vim-mode-plus-user:quick-highlight`.
- Improve accuracy for picking word under cursor by using `selection.selectWord()`.

## 0.3.10 - FIX
- Guard for `editorElement.getVisibleRowRange()` return `null` at initialization #7

## 0.3.9 - Improve
- New: config parameter highlightSelectionDelay suggested by @PaulPorfiroff.

## 0.3.8 - FIX
- No longer use TextEditor constructor directly work around warning from Atom 1.2.0

## 0.3.7 - New feature
- New highlightSelectionExcludeScopes setting allow you to exclude highlight selection by scopes.

## 0.3.6 - FIX
- Explicitly pass editor reference to highlightSelection() so that rapid pane change at Atom startup don't cause error.

## 0.3.5 - New feature
- New: highlight selection enabled by default, you can disable from settings.

## 0.3.4 - FIX
- Remove unnecessary event observation for onDidChangeScrollLeft

## 0.3.3 - FIX
- [FIX] Uncaught TypeError: Invalid Point: (NaN, 0) #2, from Atom v1.1.0
- [FIX] Deprecation waring from Atom v1.1.0.

## 0.3.2 - Add spec
- More spec coverage: statusbar indicator.
- Improve default color. now change color based on @syntax-background-color

## 0.3.1 - Add spec
- Add spec
- Precise check for decorationsByEditor has keywords.

## 0.3.0 - Improve
- Completely rewrite.
- Now decoration is created only for visible area. Greatly improve performance.

## 0.2.2 - Improve

## 0.1.12 - Doc
- Update readme to follow vim-mode's rename from command-mode to normal-mode

## 0.1.11 - BUG FIX
* [FIX] Could not highlight for Object's property like `hasOwnProperty`, `__defineGetter__`.

## 0.1.10 - Improve
* [FIX] box color broken in TILE border.

## 0.1.9 - Improve
* Doc update.

## 0.1.8 - StatusBar update.
* Now display found count on StatusBar.

## 0.1.7 - Refactoring
* Clear editor subscriptions.
* Refactoring
* Remove unused keymap directory

## 0.1.6 - Fix deprecated API, atom/atom#6867
* Use TextEditor::getLastSelection() instead of getSelection()

## 0.1.5 - Improve
* Clean up

## 0.1.3 - Improve
* Now `box` is default for config `quick-highlight.decorate`.
* Refactoring
* Refresh on Pane become active(=onDidChangeActivePaneItem()).
* Restore old cursorPosition.
* Now highlight refreshed on TextEditor::onDidChange

## 0.1.2 - Box decoration support
* Now user can choose 'highlight', 'box' for decoration preference.

## 0.1.1 - Fix
* FIX: Didn't work correctly.
* Cleanup

## 0.1.0 - First Release
* Highlight within current editor.
