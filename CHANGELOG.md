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
