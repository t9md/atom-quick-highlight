module.exports = (Base, toggle) ->
  class QuickHighlight extends Base.getClass('Operator')
    flashTarget: false
    stayAtSamePosition: true

    mutateSelection: (selection) ->
      toggle(selection.getText())

  class QuickHighlightWord extends QuickHighlight
    target: "InnerWord"

  return {QuickHighlight, QuickHighlightWord}
