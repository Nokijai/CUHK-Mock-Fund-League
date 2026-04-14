class LeagueCertificatePdfService
  # Uses a background template image (see app/assets/images/certificates/)
  # and overlays dynamic text (recipient, league, final balance, issue date).
  def initialize(league:, user:, final_balance:, ranked_at: Time.current)
    @league = league
    @user = user
    @final_balance = final_balance
    @ranked_at = ranked_at
  end

  # Generates a PDF certificate (binary string) for email attachment.
  # Keep it dependency-light (Prawn only) so mail delivery stays robust.
  def render
    require "prawn"

    Prawn::Document.new(page_size: "A4", margin: 0) do |pdf|
      if File.exist?(template_path)
        # Background is scaled to the full page to match the provided template.
        pdf.image template_path, at: [0, pdf.cursor + pdf.bounds.top], width: pdf.bounds.width, height: pdf.bounds.height
      end

      # Overlay text placements tuned to the template proportions (A4).
      # If the template image changes, adjust these bounding boxes.
      overlay_recipient_block(pdf)
      overlay_league_and_balance_block(pdf)
      overlay_issue_block(pdf)
    end.render
  end

  private

  def template_path
    Rails.root.join("app/assets/images/certificates/league_certificate_template.png")
  end

  def display_name
    (@user.respond_to?(:username) ? @user.username : nil).presence || @user.try(:name).presence || @user.email
  end

  def league_name
    @league.name.to_s
  end

  def league_end_time
    @league.end_date.in_time_zone.strftime("%a %d %b %Y, %H:%M %Z")
  end

  def final_balance_currency
    ActionController::Base.helpers.number_to_currency(@final_balance.to_f, precision: 2)
  end

  def overlay_recipient_block(pdf)
    # Recipient name area (large centered).
    pdf.fill_color "0B1F3A"
    pdf.font("Helvetica", style: :bold) do
      pdf.bounding_box([60, 405], width: pdf.bounds.width - 120, height: 70) do
        pdf.text display_name, size: 34, align: :center, valign: :center
      end
    end
  end

  def overlay_league_and_balance_block(pdf)
    # League line + final balance line beneath (centered).
    pdf.fill_color "111827"
    pdf.font("Helvetica") do
      pdf.bounding_box([85, 325], width: pdf.bounds.width - 170, height: 90) do
        pdf.text %(League: "#{league_name}"), size: 14, align: :center
        pdf.move_down 6
        pdf.text %(Final account balance: #{final_balance_currency} USD), size: 14, style: :bold, align: :center
      end
    end
  end

  def overlay_issue_block(pdf)
    # Issue line near the bottom: uses league end time as the official completion date.
    pdf.fill_color "1F2937"
    pdf.font("Helvetica") do
      pdf.bounding_box([85, 238], width: pdf.bounds.width - 170, height: 40) do
        pdf.text %(Issued on #{league_end_time}), size: 11, align: :center
      end
    end
  end
end

