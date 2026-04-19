// app/javascript/controllers/chart_controller.js
import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"   // we pinned chart.js/auto via importmap

export default class extends Controller {
  static targets = ["canvas"]

  async connect() {
    this.currency = this.data.get("currency") || "USD"
    this.target = this.data.get("target") || "mid"
    this.days = parseInt(this.data.get("days") || "60", 10)
    this.horizons = (this.data.get("horizons") || "1,2,3").split(",").map(s => parseInt(s.trim(), 10)).filter(Boolean)

    try {
      const today = new Date().toISOString().slice(0, 10)
      const fromStr = this.shift(today, -this.days)

      const [history, forecast] = await Promise.all([
        this.fetchHistory(fromStr, today),
        this.fetchForecasts()
      ])

      this.render(history, forecast, today)
    } catch (e) {
      console.error("[chart] failed:", e)
    }
  }

  shift(iso, d) { const x = new Date(iso); x.setDate(x.getDate() + d); return x.toISOString().slice(0, 10) }

  async fetchHistory(fromStr, toStr) {
    const url = `/rates?currency=${encodeURIComponent(this.currency)}&from=${encodeURIComponent(fromStr)}&to=${encodeURIComponent(toStr)}&target=${encodeURIComponent(this.target)}`
    const res = await fetch(url, { headers: { "Accept": "application/json" } })
    if (!res.ok) throw new Error(`history ${res.status}`)
    const arr = await res.json()
    return arr.map(r => ({ x: r.date, y: Number(r[this.target]) })).filter(p => !Number.isNaN(p.y))
  }

  async fetchForecasts() {
    const results = await Promise.all(this.horizons.map(async (h) => {
      const url = `/predictions?currency=${encodeURIComponent(this.currency)}&target=${encodeURIComponent(this.target)}&horizon=${h}`
      const res = await fetch(url, { headers: { "Accept": "application/json" } })
      if (!res.ok) return { h, points: [] }
      const arr = await res.json()
      return { h, points: arr.map(r => ({ x: r.predicted_for, y: Number(r.yhat) })).filter(p => !Number.isNaN(p.y)) }
    }))
    // Use the longest horizon’s points as the forecast line for now
    return results.reduce((acc, r) => (r.points.length > acc.length ? r.points : acc), [])
  }

  render(historyPts, forecastPts, todayIso) {
    const ctx = this.canvasTarget.getContext("2d")
    const labelSet = new Set(historyPts.map(p => p.x))
    forecastPts.forEach(p => labelSet.add(p.x))
    const labels = Array.from(labelSet).sort()

    const series = (pts) => {
      const m = new Map(pts.map(p => [p.x, p.y]))
      return labels.map(d => m.get(d) ?? null)
    }

    new Chart(ctx, {
      type: "line",
      data: {
        labels,
        datasets: [
          {
            label: `Actual (${this.target})`,
            data: series(historyPts),
            borderColor: "#0ea5e9",
            backgroundColor: "rgba(14,165,233,0.12)",
            borderWidth: 2,
            pointRadius: 0,
            spanGaps: true
          },
          {
            label: `Forecast (${this.target})`,
            data: series(forecastPts),
            borderColor: "#4f46e5",
            backgroundColor: "rgba(79,70,229,0.06)",
            borderWidth: 2,
            borderDash: [6, 6],
            pointRadius: 0,
            spanGaps: true
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: true, position: "bottom" }
        },
        scales: {
          x: { grid: { display: false } },
          y: {
            grid: { color: "rgba(0,0,0,0.06)" },
            ticks: { callback: v => Number(v).toLocaleString(undefined, { maximumFractionDigits: 2 }) }
          }
        }
      }
    })
  }
}
