class SchoolOwner::DiagnosticsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_school_owner

  def schema_info
    # This will help us understand what we're working with
    render json: {
      school_columns: School.column_names,
      school_column_types: School.columns_hash.transform_values { |col|
        {
          type: col.type,
          sql_type: col.sql_type,
          default: col.default
        }
      },
      associations: {
        has_many: School.reflect_on_all_associations(:has_many).map(&:name),
        has_one: School.reflect_on_all_associations(:has_one).map(&:name),
        belongs_to: School.reflect_on_all_associations(:belongs_to).map(&:name)
      },
      # Check for any accessor methods
      instance_methods: School.instance_methods(false).sort,
      # Sample a school to see actual data
      sample_data: School.first&.attributes
    }
  end

  private

  def ensure_school_owner
    redirect_to root_path unless current_user&.school_owner?
  end
end
