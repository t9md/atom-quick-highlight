module.exports = class StatusBarManager {
  constructor () {
    this.span = document.createElement('span')

    this.element = document.createElement('div')
    this.element.id = 'status-bar-quick-highlight'
    this.element.className = 'block'
    this.element.appendChild(this.span)

    this.container = document.createElement('div')
    this.container.className = 'inline-block'
    this.container.appendChild(this.element)
  }

  initialize (statusBar) {
    this.statusBar = statusBar
  }

  update (count) {
    this.span.className = atom.config.get('quick-highlight.countDisplayStyles')
    this.span.textContent = count
    this.element.style.display = 'inline-block'
  }

  clear () {
    this.element.style.display = 'none'
  }

  attach () {
    const displayPosition = atom.config.get('quick-highlight.countDisplayPosition')

    this.tile = this.statusBar[`add${displayPosition}Tile`]({
      item: this.container,
      priority: atom.config.get('quick-highlight.countDisplayPriority')
    })
  }

  detach () {
    if (this.tile) this.tile.destroy()
  }
}
