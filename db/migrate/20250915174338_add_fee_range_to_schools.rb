class AddFeeRangeToSchools < ActiveRecord::Migration[8.0]
  def change
    add_column :schools, :min_annual_fee, :decimal, precision: 10, scale: 2
    add_column :schools, :max_annual_fee, :decimal, precision: 10, scale: 2
    add_column :schools, :fee_currency, :string, default: 'THB', null: false
  end
end
