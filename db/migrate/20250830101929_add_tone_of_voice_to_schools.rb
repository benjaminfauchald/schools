class AddToneOfVoiceToSchools < ActiveRecord::Migration[8.0]
  def change
    add_column :schools, :tone_of_voice, :text
  end
end
