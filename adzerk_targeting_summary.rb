# Run in console
# Prints CSV to summarize flight targeting
# Summary sheet: https://docs.google.com/spreadsheets/d/1MY2N5Abo2lERhRWladYuW9RZB0rEDwP-Spx7sqqEmWA

api = Adzerk::Api.new
advertisers = api.all_advertisers

advertisers.each do |advertiser|
  campaigns = api.advertiser_campaigns(advertiser_id: advertiser.id)[:items]

  campaigns.each do |campaign|
    adzerk_campaign = Adzerk::Campaign.new campaign

    flights = api.campaign_flights(campaign_id: adzerk_campaign.id)

    flights.each do |flight|
      sanitized_keywords = ''

      if flight.keywords
        sanitized_keywords = flight.keywords.gsub("\n", '\n').gsub(' ', '')
      end

      sanitized_custom_targeting = ''

      if flight.custom_targeting
        sanitized_custom_targeting = flight.custom_targeting.gsub("\n", '\n').gsub(' ', '')
      end

      puts "\"#{flight.id}\",\"#{flight.priority_id}\",\"#{sanitized_custom_targeting}\",\"#{sanitized_keywords}\""
    end
  end
end
