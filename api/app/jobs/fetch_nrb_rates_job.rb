# app/jobs/fetch_nrb_rates_job.rb
class FetchNrbRatesJob < ApplicationJob
  queue_as :default

  BASE = ENV.fetch("NRB_BASE_URL", "https://www.nrb.org.np/api/forex/v1")

  # Usage:
  # FetchNrbRatesJob.perform_now(from: "2025-01-01", to: "2026-02-14", per_page: 100)
  def perform(from:, to:, per_page: 100)
    page = 1
    loop do
      res = HTTParty.get("#{BASE}/rates", query: { from:, to:, page:, per_page: })
      unless res.success?
        Rails.logger.error "NRB error #{res.code} #{res.body}"
        break
      end

      json = res.parsed_response
      payload = json.dig("data", "payload") || []
      break if payload.empty?

      payload.each do |day|
        date = Date.parse(day["date"])
        pub  = parse_time(day["published_on"])
        mod  = parse_time(day["modified_on"])

        (day["rates"] || []).each do |r|
          iso3 = r.dig("currency", "iso3")
          name = r.dig("currency", "name")
          unit = (r.dig("currency", "unit") || 1).to_i.nonzero? || 1

          currency = Currency.find_or_create_by!(iso3: iso3) do |c|
            c.name = name
            c.unit = unit
          end
          currency.update!(unit: unit) if currency.unit != unit

          buy_raw  = to_decimal(r["buy"])
          sell_raw = to_decimal(r["sell"])
          buy      = buy_raw  / unit
          sell     = sell_raw / unit
          mid      = (buy + sell) / 2

          ExchangeRate.upsert(
            {
              currency_id: currency.id, date: date,
              published_on: pub, modified_on: mod,
              buy_raw: buy_raw, sell_raw: sell_raw,
              buy: buy, sell: sell, mid: mid,
              source: "NRB",
              created_at: Time.current, updated_at: Time.current
            },
            unique_by: %i[currency_id date]
          )
        end
      end

      pages = (json.dig("pagination", "pages") || 1).to_i
      break if page >= pages
      page += 1
    end
  end

  private

  def to_decimal(val)
    BigDecimal(val.to_s)
  end

  def parse_time(val)
    Time.zone.parse(val.to_s) rescue nil
  end
end
