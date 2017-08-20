const {CompositeDisposable, Emitter} = require("atom")

let KeywordManager

module.exports = {
  activate(state) {
    this.emitter = new Emitter()

    this.subscriptions = new CompositeDisposable(
      atom.commands.add("atom-text-editor:not([mini])", {
        "quick-highlight:toggle": () => this.toggle(),
        "quick-highlight:clear": () => this.keywordManager && this.keywordManager.clear(),
      }),
      atom.config.observe("quick-highlight.highlightSelection", value => {
        if (value) this.getKeywordmanager() // To initialize
      })
    )
  },

  deactivate() {
    if (this.keywordManager) this.keywordManager.destroy()
    this.subscriptions.dispose()
    this.keywordManager = null
    this.subscriptions = null
  },

  getKeywordmanager() {
    if (!KeywordManager) KeywordManager = require("./keyword-manager")
    if (!this.keywordManager) this.keywordManager = new KeywordManager(this.emitter, this.statusBar)
    return this.keywordManager
  },

  toggle(keyword) {
    this.getKeywordmanager().toggle(keyword)
  },

  onDidChangeHighlight(fn) {
    return this.emitter.on("did-change-highlight", fn)
  },

  provideQuickHighlight() {
    return {onDidChangeHighlight: this.onDidChangeHighlight.bind(this)}
  },

  consumeStatusBar(statusBar) {
    this.statusBar = statusBar
    if (this.keywordManager) {
      this.keywordManager.statusBarManager.initialize(this.statusBar)
      this.keywordManager.statusBarManager.attach()
    }
  },

  consumeVim({Base, registerCommandFromSpec}) {
    let vmpCommands
    const commandSpec = {
      commandPrefix: "vim-mode-plus-user",
      getClass: name => {
        if (!vmpCommands) {
          vmpCommands = require("./load-vmp-commands")(Base, this.toggle.bind(this))
        }
        return vmpCommands[name]
      },
    }

    this.subscriptions.add(
      registerCommandFromSpec("QuickHighlight", commandSpec),
      registerCommandFromSpec("QuickHighlightWord", commandSpec)
    )
  },
}
