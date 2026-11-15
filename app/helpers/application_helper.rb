module ApplicationHelper
  def link_with_filter_to(path, *args, &block)
    if path.start_with?('/')
      if path.include?('?')
        path += '&'
      else
        path += '?'
      end
    end
    link_to(path + filter_query_string, *args, &block)
  end

  private

  # The filter is the same for every link on a page, so build it once per request
  def filter_query_string
    @filter_query_string ||= raw_ranking_configuration.map do |key, value|
      "#{key}=#{URI.encode_www_form_component(value.to_s)}&"
    end.join
  end
end
