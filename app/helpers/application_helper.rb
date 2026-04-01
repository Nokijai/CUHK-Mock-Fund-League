module ApplicationHelper
  # Renders a timestamp with a safe server fallback, then JS rewrites it to browser timezone.
  def user_local_time(time, nil_text: "—", include_zone: false)
    return nil_text if time.blank?

    timestamp = time.respond_to?(:in_time_zone) ? time.in_time_zone : Time.zone.parse(time.to_s)
    fallback_text = include_zone ? timestamp.strftime("%Y-%m-%d %H:%M %Z") : timestamp.strftime("%Y-%m-%d %H:%M")

    time_tag(
      timestamp,
      fallback_text,
      data: {
        user_local_time: "true",
        utc_iso: timestamp.utc.iso8601,
        include_zone: include_zone.to_s
      }
    )
  rescue ArgumentError, TypeError
    nil_text
  end
end
