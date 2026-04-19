import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["amount","todayRate","bestRate","todayAmt","bestAmt","diffAmt"]

  connect() { this.recalc() }

  setAmount(e) {
    const v = parseFloat(e.currentTarget.dataset.value)
    if (!Number.isNaN(v)) {
      this.amountTarget.value = v
      this.recalc()
    }
  }

  recalc() {
    const amt   = this.num(this.amountTarget?.value)
    const today = this.num(this.todayRateTarget?.value)
    const best  = this.num(this.bestRateTarget?.value)

    if ([amt, today, best].some(Number.isNaN)) {
      this.todayAmtTarget.textContent = "—"
      this.bestAmtTarget.textContent  = "—"
      this.diffAmtTarget.textContent  = "—"
      this.diffAmtTarget.className    = "text-xl font-semibold text-slate-400"
      return
    }

    const todayAmt = amt * today
    const bestAmt  = amt * best
    const diff     = bestAmt - todayAmt

    this.todayAmtTarget.textContent = this.fmt(todayAmt)
    this.bestAmtTarget.textContent  = this.fmt(bestAmt)
    this.diffAmtTarget.textContent  = (diff >= 0 ? "+" : "") + this.fmt(diff)
    this.diffAmtTarget.className    = `text-xl font-semibold ${diff >= 0 ? "text-green-700" : "text-rose-700"}`
  }

  num(v) {
    if (v == null) return NaN
    const s = String(v).replace(/[\u00A0,]/g, "").trim()
    return parseFloat(s)
  }

  fmt(x) {
    if (Number.isNaN(x)) return "—"
    return Number(x).toLocaleString(undefined, { maximumFractionDigits: 2 })
  }
}
