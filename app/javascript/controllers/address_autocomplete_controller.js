import { Controller } from "@hotwired/stimulus"

// Free, keyless geocoding — komoot's public Photon instance (OSM data).
// No billing account, no API key, no server-side setup. Tradeoff: OSM
// address coverage is good in cities but spottier in rural areas, and
// there's no uptime SLA on the public instance (self-hosting Photon is
// the fallback if that ever becomes a problem).
const PHOTON_URL = "https://photon.komoot.io/api/"
const DEBOUNCE_MS = 300
const MIN_QUERY_LENGTH = 3

const ACTIVE_CLASSES = [ "bg-accent-soft" ]

// Connects to app/views/rides/new.html.erb's pickup/dropoff address blocks.
// The search box is the only way to set an address — line1/city/state/zip
// are hidden fields it fills in on selection, submitted as part of the form.
export default class extends Controller {
  static targets = [ "mount", "line1", "city", "state", "zip", "lat", "lng" ]

  connect() {
    this.activeIndex = -1
    this.searchToken = 0

    this.wrapper = document.createElement("div")
    this.wrapper.className = "relative"

    this.input = document.createElement("input")
    this.input.type = "text"
    this.input.autocomplete = "off"
    this.input.placeholder = "Start typing an address…"
    this.input.className = "w-full rounded-lg border border-line bg-panel px-3 py-2 text-sm text-ink placeholder:text-faint focus:border-accent focus:outline-none focus:ring-2 focus:ring-accent/20 transition-shadow"
    this.input.setAttribute("role", "combobox")
    this.input.setAttribute("aria-expanded", "false")
    this.input.setAttribute("aria-autocomplete", "list")

    this.results = document.createElement("ul")
    this.results.className = "absolute z-10 w-full rounded-lg border border-line bg-panel shadow-lg mt-1 max-h-56 overflow-y-auto empty:hidden"
    this.results.setAttribute("role", "listbox")

    this.wrapper.append(this.input, this.results)
    this.mountTarget.appendChild(this.wrapper)

    this.input.addEventListener("input", () => this.onInput())
    this.input.addEventListener("keydown", (event) => this.onKeydown(event))
    this.input.addEventListener("blur", () => setTimeout(() => this.clearResults(), 150))

    // A failed form submission (for an unrelated field) re-renders this page
    // with the hidden fields still populated from the previous attempt —
    // without this the chosen address would silently vanish from view.
    this.input.value = [ this.line1Target.value, this.cityTarget.value, this.stateTarget.value, this.zipTarget.value ]
      .filter(Boolean)
      .join(", ")
  }

  onInput() {
    clearTimeout(this.debounceTimer)

    const query = this.input.value.trim()
    if (query.length < MIN_QUERY_LENGTH) {
      this.clearResults()
      return
    }

    this.debounceTimer = setTimeout(() => this.search(query), DEBOUNCE_MS)
  }

  onKeydown(event) {
    const items = Array.from(this.results.children)

    if (event.key === "ArrowDown") {
      if (!items.length) return
      event.preventDefault()
      this.setActive(items, (this.activeIndex + 1) % items.length)
    } else if (event.key === "ArrowUp") {
      if (!items.length) return
      event.preventDefault()
      this.setActive(items, (this.activeIndex - 1 + items.length) % items.length)
    } else if (event.key === "Enter") {
      if (this.activeIndex < 0 || !this.features?.[this.activeIndex]) return
      event.preventDefault()
      this.select(this.features[this.activeIndex])
    } else if (event.key === "Escape") {
      this.clearResults()
    }
  }

  setActive(items, index) {
    items[this.activeIndex]?.classList.remove(...ACTIVE_CLASSES)
    items[this.activeIndex]?.setAttribute("aria-selected", "false")
    this.activeIndex = index
    items[index]?.classList.add(...ACTIVE_CLASSES)
    items[index]?.setAttribute("aria-selected", "true")
    items[index]?.scrollIntoView({ block: "nearest" })
  }

  async search(query) {
    const token = ++this.searchToken
    this.renderMessage("Searching…")

    const params = new URLSearchParams({ q: query, limit: "5", lang: "en" })

    let features
    try {
      const response = await fetch(`${PHOTON_URL}?${params}`)
      ;({ features } = await response.json())
    } catch (error) {
      console.error(error)
      if (token === this.searchToken) this.renderMessage("Search failed — try again in a moment.")
      return
    }

    if (token !== this.searchToken) return // a newer keystroke's search already landed

    this.renderResults(features.filter((f) => f.properties.countrycode === "US"))
  }

  renderMessage(text) {
    this.features = undefined
    this.activeIndex = -1
    this.results.innerHTML = ""

    const li = document.createElement("li")
    li.textContent = text
    li.className = "px-3 py-2 text-sm text-muted"
    this.results.appendChild(li)
    this.input.setAttribute("aria-expanded", "true")
  }

  renderResults(features) {
    this.features = features
    this.activeIndex = -1
    this.results.innerHTML = ""

    if (!features.length) {
      this.renderMessage("No matches — try a different search.")
      return
    }

    features.forEach((feature, index) => {
      const { city, state, postcode } = feature.properties

      const primary = document.createElement("div")
      primary.textContent = this.formatLine1(feature.properties)

      const secondary = document.createElement("div")
      secondary.className = "text-xs text-faint"
      secondary.textContent = [ city, state, postcode ].filter(Boolean).join(", ")

      const li = document.createElement("li")
      li.className = "px-3 py-2 cursor-pointer hover:bg-accent-soft transition-colors"
      li.setAttribute("role", "option")
      li.setAttribute("aria-selected", "false")
      li.append(primary, secondary)
      li.addEventListener("mousedown", (event) => {
        event.preventDefault()
        this.select(feature)
      })
      li.addEventListener("mousemove", () => this.setActive(Array.from(this.results.children), index))
      this.results.appendChild(li)
    })

    this.input.setAttribute("aria-expanded", "true")
  }

  formatLine1({ housenumber, street, name }) {
    return [ housenumber, street ].filter(Boolean).join(" ") || name || ""
  }

  select(feature) {
    const { city, state, postcode } = feature.properties

    this.input.value = [ this.formatLine1(feature.properties), city, state, postcode ].filter(Boolean).join(", ")
    this.line1Target.value = this.formatLine1(feature.properties)
    this.cityTarget.value = city || ""
    this.stateTarget.value = state || ""
    this.zipTarget.value = postcode || ""

    // GeoJSON coordinate order is [lng, lat], not [lat, lng] — easy to get
    // backwards. Only present for a picked (geocoded) result, never for a
    // hand-typed address, which is why Ride#trip_miles and
    // ProviderRanking::DistanceScore treat missing coordinates as
    // expected, not an error.
    if (this.hasLatTarget && this.hasLngTarget) {
      const [ lng, lat ] = feature.geometry?.coordinates ?? []
      this.latTarget.value = lat ?? ""
      this.lngTarget.value = lng ?? ""
    }

    this.clearResults()
  }

  clearResults() {
    this.features = undefined
    this.activeIndex = -1
    this.results.innerHTML = ""
    this.input.setAttribute("aria-expanded", "false")
  }
}
