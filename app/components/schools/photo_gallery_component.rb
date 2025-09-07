# frozen_string_literal: true

class Schools::PhotoGalleryComponent < ViewComponent::Base
  def initialize(media_items:)
    @media_items = media_items
  end

  private

  attr_reader :media_items

  def render?
    photos.any?
  end

  def photos
    @photos ||= media_items.select { |item| item.kind == "photo" }.sort_by(&:sort_order)
  end

  def logo
    @logo ||= media_items.find { |item| item.kind == "logo" }
  end

  def hero_photo
    photos.first
  end

  def thumbnail_photos
    photos
  end

  def gallery_id
    "photo-gallery-#{object_id}"
  end

  def modal_id
    "photo-modal-#{object_id}"
  end

  def carousel_id
    "photo-carousel-#{object_id}"
  end
end
