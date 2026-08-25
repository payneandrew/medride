import { Controller } from "@hotwired/stimulus"

// Fades out and removes a flash message a few seconds after it appears.
// Connects fresh every time (including on Turbo Stream updates, since the
// element is replaced wholesale), so a new message always gets its own timer.
export default class extends Controller {
  static values = { delay: { type: Number, default: 4000 } }

  connect() {
    this.timeout = setTimeout(() => this.dismiss(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.style.transition = "opacity 300ms ease, transform 300ms ease"
    this.element.style.opacity = "0"
    this.element.style.transform = "translateY(-4px)"
    setTimeout(() => this.element.remove(), 300)
  }
}
