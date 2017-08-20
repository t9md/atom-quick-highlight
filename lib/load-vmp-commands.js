module.exports = function(Base, toggle) {
  class QuickHighlight extends Base.getClass("Operator") {
    initialize() {
      super.initialize()
      this.flashTarget = false
      this.stayAtSamePosition = true
    }

    mutateSelection(selection) {
      toggle(selection.getText())
    }
  }

  class QuickHighlightWord extends QuickHighlight {
    initialize() {
      super.initialize()
      this.target = "InnerWord"
    }
  }
  return {QuickHighlight, QuickHighlightWord}
}
