country_mapping = {}
state_mapping = {}

location_misses = []
country_misses = []
state_misses = []

Region.find_each do |region|
  puts "Assigning region #{region.id}"

  begin
    location = GeocodingService.reverse_geocode \
      latitude: region.location.latitude,
      longitude: region.location.longitude
  rescue Region::CantDetermineLocationError => e
    puts "No location for region #{region.id}"
    location_misses << region.id
    next
  end

  if location.country_code
    country = location.country_code.downcase

    if country_mapping.has_key? country
      country_mapping[country] << region.id
    else
      country_mapping[country] = [region.id]
    end
  else
    puts "No country code for region #{region.id}"
    country_misses << region.id
  end

  if location.state
    state = location.state.downcase

    if state_mapping.has_key? state
      state_mapping[state] << region.id
    else
      state_mapping[state] = [region.id]
    end
  else
    puts "No state code for region #{region.id}"
    state_misses << region.id
  end
end
