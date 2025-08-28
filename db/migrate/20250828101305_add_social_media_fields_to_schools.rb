class AddSocialMediaFieldsToSchools < ActiveRecord::Migration[8.0]
  def change
    add_column :schools, :facebook_url, :string
    add_column :schools, :line_id, :string
    add_column :schools, :whatsapp_number, :string
  end
end
