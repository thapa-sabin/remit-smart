# api/lib/tasks/ingest.rake
namespace :ingest do
  desc "Backfill NRB forex rates over N days"
  task :backfill, [:days] => :environment do |_, args|
    days = (ENV['DAYS'] || args[:days] || 365).to_i
    from = (Date.today - days).to_s
    to   = Date.today.to_s

    require Rails.root.join("app/jobs/fetch_nrb_rates_job")
    FetchNrbRatesJob.perform_now(from: from, to: to, per_page: 100)

    puts "Backfill done: #{from} -> #{to}"
  end
end
