# Override class to define new method
class Adzerk::Api
  def get_flight_instant_count(flight_adzerk_id)
    url = "#{ADZERK_API_BASE}/instantcounts/flight/#{flight_adzerk_id}"
    result = JSON.parse(Typhoeus.get(url, headers: headers).body).deep_symbolize_keys
    result[:flights][flight_adzerk_id.to_s.to_sym]
  end
end

# Example usage
api = Adzerk::Api.new

org = Organization.find 4526
campaigns = org.advertising_campaigns
campaign = org.advertising_campaigns.first # id 3667
flight = campaign.flight # id 3667
kevel_revenue = api.get_flight_instant_count(flight.adzerk_id)[:revenue].round(2) # 8702.85
