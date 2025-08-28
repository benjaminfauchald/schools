# frozen_string_literal: true

class Schools::ContactInfoComponent < ViewComponent::Base
  def initialize(contact_info:, location_data: {})
    @contact_info = contact_info
    @location_data = location_data
  end

  private

  attr_reader :contact_info, :location_data

  def render?
    contact_items.any? || location_items.any?
  end

  def contact_items
    @contact_items ||= build_contact_items
  end

  def location_items
    @location_items ||= build_location_items
  end

  def build_contact_items
    items = []

    if contact_info[:phone]
      items << {
        label: 'Phone',
        value: contact_info[:phone],
        icon: 'phone',
        link: "tel:#{contact_info[:phone].gsub(/\D/, '')}",
        format: :phone
      }
    end

    if contact_info[:email]
      items << {
        label: 'Email',
        value: contact_info[:email],
        icon: 'envelope',
        link: "mailto:#{contact_info[:email]}",
        format: :email
      }
    end

    if contact_info[:website]
      items << {
        label: 'Website',
        value: contact_info[:website],
        icon: 'globe',
        link: contact_info[:website],
        format: :url
      }
    end

    if contact_info[:facebook_url]
      items << {
        label: 'Facebook',
        value: contact_info[:facebook_url],
        icon: 'square-2-stack',
        link: contact_info[:facebook_url],
        format: :url
      }
    end

    if contact_info[:line_id]
      items << {
        label: 'Line',
        value: "@#{contact_info[:line_id]}",
        icon: 'chat-bubble-left-right',
        link: "https://line.me/ti/p/~#{contact_info[:line_id]}",
        format: :social
      }
    end

    if contact_info[:whatsapp_number]
      items << {
        label: 'WhatsApp',
        value: contact_info[:whatsapp_number],
        icon: 'chat-bubble-oval-left',
        link: "https://wa.me/#{contact_info[:whatsapp_number].gsub(/\D/, '')}",
        format: :phone
      }
    end

    items
  end

  def build_location_items
    items = []

    if contact_info[:address]
      items << {
        label: 'Address',
        value: contact_info[:address],
        icon: 'map-pin',
        link: contact_info[:google_maps_url],
        format: nil
      }
    end

    if location_data[:district]
      items << {
        label: 'District',
        value: location_data[:district],
        icon: nil,
        format: nil
      }
    end

    if location_data[:province]
      items << {
        label: 'Province',
        value: location_data[:province],
        icon: nil,
        format: nil
      }
    end

    items
  end

end