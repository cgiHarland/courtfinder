class CourtSearch
  def initialize(query, options={})
    @query = query
    @options = options
  end

  def results
    if postcode_search?
      {:courts => search_postcode, :court_types => [], :areas_of_law => []}
    else
      {:courts => Court.search(@query), :court_types => CourtType.search(@query), :areas_of_law => AreaOfLaw.search(@query)}
    end
  end

  def search_postcode
    Court.near(latlng_from_postcode(@query), @options[:distance] || 20, :order => :distance)
  end

  def latlng_from_postcode(postcode)
    service_available = Rails.application.config.postcode_lookup_service_url rescue false
    json = RestClient.post Rails.application.config.postcode_lookup_service_url, { :searchtext => postcode, :searchbtn => 'Submit' }
    latlon = JSON.parse json
    [latlon[0]['lat'], latlon[0]['long']]
  end

  def postcode_search?
    @query =~ /^([g][i][r][0][a][a])$|^((([a-pr-uwyz]{1}\d{1,2})|([a-pr-uwyz]{1}[a-hk-y]{1}\d{1,2})|([a-pr-uwyz]{1}\d{1}[a-hjkps-uw]{1})|([a-pr-uwyz]{1}[a-hk-y]{1}\d{1}[a-z]{1}))\d[abd-hjlnp-uw-z]{2})$/i
  end
end