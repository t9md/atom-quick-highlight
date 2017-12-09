module.exports = function(getClass, toggle) {
  class QuickHighlight extends getClass("Operator") {
    initialize() {
      this.flashTarget = false
      this.stayAtSamePosition = true
      return super.initialize()
    }

    mutateSelection(selection) {
      toggle(selection.getText())
    }
  }

  class QuickHighlightWord extends QuickHighlight {
    initialize() {
      this.target = "InnerWord"
      return super.initialize()
    }
  }
  return {QuickHighlight, QuickHighlightWord}
}
