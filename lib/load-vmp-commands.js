module.exports = function(Base, toggle) {
  class QuickHighlight extends Base.getClass("Operator") {
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
