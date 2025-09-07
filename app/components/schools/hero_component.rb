# frozen_string_literal: true

class Schools::HeroComponent < ViewComponent::Base
  def initialize(hero_data:, contact_info:, school: nil)
    @hero_data = hero_data
    @contact_info = contact_info
    @school = school
  end

  private

  attr_reader :hero_data, :contact_info, :school

  def school_name
    hero_data[:name]
  end

  def hero_image_url
    hero_data[:hero_image]&.url || hero_data[:logo]&.url
  end

  def rating_display
    return unless hero_data[:rating]

    rating = hero_data[:rating]
    {
      stars: rating[:stars_display],
      value: rating[:rating],
      count: rating[:total_ratings],
      source: rating[:source]
    }
  end

  def key_stats
    hero_data[:key_stats] || []
  end

  def contact_actions
    actions = []

    # Only show claim button for unclaimed schools - no other buttons
    if should_show_claim_button?
      actions << claim_button_action
    end

    actions
  end

  def should_show_claim_button?
    return false unless school
    return false if school.active_claims?

    if helpers.user_signed_in?
      user = helpers.current_user
      return false unless user&.school_owner?
      # Don't show if user can already edit this school or has pending/active claim
      !user.can_edit_school?(school) && !user.school_claims.where(school: school).where(status: [ "pending", "approved" ], revoked_at: nil).exists?
    else
      # Show for anonymous users if school has no active claims
      true
    end
  end

  def claim_button_action
    {
      label: "Claim This School",
      icon: "building-office-2",
      url: helpers.new_direct_claim_path(school_id: school.id),
      primary: true,
      claim_button: true
    }
  end

  def stat_icon_svg(icon_name)
    helpers.heroicon(icon_name, css_class: "w-5 h-5 text-blue-600")
  end

  def action_button_classes(action)
    if action[:claim_button]
      "bg-green-600 hover:bg-green-700 text-white shadow-lg"
    elsif action[:contact_button]
      "bg-blue-600 hover:bg-blue-700 text-white shadow-lg"
    elsif action[:primary]
      "bg-blue-600 hover:bg-blue-700 text-white"
    else
      "bg-white hover:bg-gray-50 text-gray-900 border border-gray-300"
    end
  end

  def action_icon_svg(icon_name)
    helpers.heroicon(icon_name, css_class: "w-4 h-4 mr-2")
  end
end
