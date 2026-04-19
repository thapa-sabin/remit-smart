# app/helpers/ui_helper.rb
module UiHelper
  FLAGS = {
    "USD"=>"🇺🇸","NPR"=>"🇳🇵","INR"=>"🇮🇳","AED"=>"🇦🇪","PHP"=>"🇵🇭",
    "EUR"=>"🇪🇺","GBP"=>"🇬🇧","AUD"=>"🇦🇺","CHF"=>"🇨🇭","JPY"=>"🇯🇵",
    "CNY"=>"🇨🇳","CAD"=>"🇨🇦","BDT"=>"🇧🇩","NGN"=>"🇳🇬","PKR"=>"🇵🇰",
    "SGD"=>"🇸🇬","SAR"=>"🇸🇦","QAR"=>"🇶🇦","THB"=>"🇹🇭","MYR"=>"🇲🇾",
    "KRW"=>"🇰🇷","SEK"=>"🇸🇪","DKK"=>"🇩🇰","HKD"=>"🇭🇰","KWD"=>"🇰🇼",
    "BHD"=>"🇧🇭","OMR"=>"🇴🇲"
  }.freeze

  CURRENCY_NAMES = {
    "USD"=>"US Dollar",
    "NPR"=>"Nepalese Rupee",
    "INR"=>"Indian Rupee",
    "AED"=>"UAE Dirham",
    "PHP"=>"Philippine Peso",
    "EUR"=>"Euro",
    "GBP"=>"British Pound Sterling",
    "AUD"=>"Australian Dollar",
    "CHF"=>"Swiss Franc",
    "JPY"=>"Japanese Yen",
    "CNY"=>"Chinese Yuan",
    "CAD"=>"Canadian Dollar",
    "BDT"=>"Bangladeshi Taka",
    "NGN"=>"Nigerian Naira",
    "PKR"=>"Pakistani Rupee",
    "SGD"=>"Singapore Dollar",
    "SAR"=>"Saudi Riyal",
    "QAR"=>"Qatari Riyal",
    "THB"=>"Thai Baht",
    "MYR"=>"Malaysian Ringgit",
    "KRW"=>"South Korean Won",
    "SEK"=>"Swedish Krona",
    "DKK"=>"Danish Krone",
    "HKD"=>"Hong Kong Dollar",
    "KWD"=>"Kuwaiti Dinar",
    "BHD"=>"Bahraini Dinar",
    "OMR"=>"Omani Rial"
  }.freeze

  def flag_for(iso3) = FLAGS[iso3] || "🏳️"

  def currency_label(iso3)
    "#{flag_for(iso3)} #{iso3} — #{CURRENCY_NAMES[iso3] || iso3}"
  end

  def fmt_rate(v, precision: 4)
    return "—" if v.nil?
    number_with_precision(v, precision: precision)
  end

  def fmt_pct(p, precision: 2)
    return "—" if p.nil?
    "#{p.positive? ? '+' : ''}#{number_with_precision(p, precision: precision)}%"
  end

  def delta_badge_classes(delta)
    base = "inline-flex items-center rounded px-2 py-0.5 text-xs font-medium ring-1"
    return "#{base} bg-green-50 text-green-700 ring-green-200" if delta > 0
    return "#{base} bg-slate-100 text-slate-700 ring-slate-200" if delta == 0
    "#{base} bg-rose-50 text-rose-700 ring-rose-200"
  end

  # ---- Volatility (simple): stdev of last 14 days vs today rate ----
  def volatility_tag(recent_rates, today_rate)
    return nil if recent_rates.blank? || today_rate.to_f.zero?

    vals = recent_rates.last(14).map { |(_, v)| v.to_f }
    return nil if vals.size < 5

    mean  = vals.sum / vals.size
    var   = vals.map { |v| (v - mean) ** 2 }.sum / (vals.size - 1)
    stdev = Math.sqrt(var)
    vol_pct = (stdev / today_rate.to_f) * 100.0

    level, klass =
      if vol_pct >= 1.0
        ["High",   "bg-rose-50 text-rose-700 ring-rose-200"]
      elsif vol_pct >= 0.4
        ["Medium", "bg-amber-50 text-amber-700 ring-amber-200"]
      else
        ["Low",    "bg-emerald-50 text-emerald-700 ring-emerald-200"]
      end

    {
      label: level,
      pct: vol_pct,
      css: "inline-flex rounded px-2 py-0.5 text-xs font-medium ring-1 #{klass}"
    }
  end

  # ---- Sparkline path (inline SVG) for last 30 days ----
  # data: [ [date, value], ... ] in ascending order
  def sparkline_path(data, width: 220, height: 48, pad: 4)
    return "" if data.blank?

    values = data.map { |(_, v)| v.to_f }
    min, max = values.minmax
    range = (max - min).nonzero? || 1.0
    step  = (width - pad * 2).to_f / (values.size - 1).clamp(1, 10_000)

    points = values.each_with_index.map do |v, i|
      x = pad + i * step
      y = height - pad - ((v - min) / range) * (height - pad * 2)
      [x.round(2), y.round(2)]
    end

    "M #{points.first.join(' ')} " + points.drop(1).map { |x, y| "L #{x} #{y}" }.join(" ")
  end
end
# --- Corridor presets (quick shortcuts) ---
def corridor_presets
  # Adjust or re-order as you like; these are commonly used corridors
  [
    { from: "AED", to: "NPR" }, # UAE → Nepal
    { from: "AUD", to: "NPR" }, # US  → Nepal
    { from: "USD", to: "NPR" }, # US  → Nepal
    { from: "MYR", to: "NPR" }, # US  → Nepal
    { from: "KRW", to: "NPR" } # US  → Nepal
  ]
end

def corridor_preset_label(from, to)
  "#{flag_for(from)} #{from} → #{flag_for(to)} #{to}"
end

def corridor_chip_classes(active:)
  base = "inline-flex items-center rounded-full border px-3 py-1 text-sm transition-colors"
  return "#{base} border-indigo-600 bg-indigo-600 text-white hover:bg-indigo-700" if active
  "#{base} border-slate-300 bg-white text-slate-800 hover:bg-slate-50"
end

def preset_active?(from, to)
  @from.to_s.upcase == from.to_s.upcase && @to.to_s.upcase == to.to_s.upcase
end
