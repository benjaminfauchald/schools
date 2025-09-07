class DirectClaimForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :email, :string
  attribute :evidence_url, :string
  attribute :notes, :string

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  def initialize(attributes = {})
    super
  end

  def self.model_name
    ActiveModel::Name.new(self, nil, "DirectClaim")
  end

  def persisted?
    false
  end
end
