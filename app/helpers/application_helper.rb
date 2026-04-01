module ApplicationHelper
  def format_datetime(datetime, format: :long)
    return "" if datetime.blank?
    
    if format == :short
      datetime.strftime("%Y-%m-%d %H:%M")
    else
      datetime.strftime("%b %-d, %Y %I:%M %p")
    end
  end
end
