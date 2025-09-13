require 'rails_helper'

RSpec.describe AuditLog, type: :model do
  let(:school) { create(:school) }
  let(:user) { create(:user) }
  let(:audit_log) { create(:audit_log, auditable: school, user_id: user.id) }

  describe 'associations' do
    it { should belong_to(:auditable) }
  end

  describe 'validations' do
    subject { build(:audit_log, auditable: school) }

    it { should validate_presence_of(:action) }
    it { should validate_presence_of(:auditable_type) }
    it { should validate_presence_of(:auditable_id) }

    it 'validates action inclusion' do
      valid_actions = %w[create update delete submit approve reject suspend publish unpublish]
      valid_actions.each do |action|
        audit_log = build(:audit_log, auditable: school, action: action)
        expect(audit_log).to be_valid
      end

      audit_log = build(:audit_log, auditable: school, action: 'invalid')
      expect(audit_log).not_to be_valid
      expect(audit_log.errors[:action]).to include('is not included in the list')
    end
  end

  describe 'scopes' do
    let!(:create_log) { create(:audit_log, auditable: school, action: 'create') }
    let!(:update_log) { create(:audit_log, auditable: school, action: 'update') }
    let!(:school_log) { create(:audit_log, auditable: school) }
    let!(:place_log) { create(:audit_log, auditable: create(:place)) }
    let!(:user_log) { create(:audit_log, auditable: school, user_id: user.id) }
    let!(:no_user_log) { create(:audit_log, auditable: school, user_id: nil) }

    describe '.by_action' do
      it 'filters by action' do
        expect(AuditLog.by_action('create')).to include(create_log)
        expect(AuditLog.by_action('create')).not_to include(update_log)
      end
    end

    describe '.by_model' do
      it 'filters by model type' do
        expect(AuditLog.by_model('School')).to include(school_log)
        expect(AuditLog.by_model('School')).not_to include(place_log)
      end
    end

    describe '.recent' do
      it 'returns recent logs ordered by created_at desc' do
        old_log = create(:audit_log, auditable: school, created_at: 1.week.ago)
        new_log = create(:audit_log, auditable: school, created_at: 1.hour.ago)

        recent = AuditLog.recent(10)
        expect(recent).to include(new_log)
        expect(recent).to include(old_log)
        # Check ordering by comparing specific logs
        school_logs = recent.select { |log| log.auditable == school }
        expect(school_logs.first.created_at).to be > school_logs.last.created_at
      end

      it 'limits results' do
        10.times { create(:audit_log, auditable: school) }
        expect(AuditLog.recent(5).count).to eq(5)
      end
    end

    describe '.for_record' do
      it 'returns logs for specific record' do
        expect(AuditLog.for_record(school)).to include(school_log)
        expect(AuditLog.for_record(school)).not_to include(place_log)
      end
    end

    describe '.by_user' do
      it 'filters by user_id' do
        expect(AuditLog.by_user(user.id)).to include(user_log)
        expect(AuditLog.by_user(user.id)).not_to include(no_user_log)
      end
    end
  end

  describe 'instance methods' do
    describe '#action_description' do
      it 'returns human-readable action descriptions' do
        audit_log.action = 'create'
        expect(audit_log.action_description).to eq('Created')

        audit_log.action = 'update'
        expect(audit_log.action_description).to eq('Updated')

        audit_log.action = 'delete'
        expect(audit_log.action_description).to eq('Deleted')

        audit_log.action = 'submit'
        expect(audit_log.action_description).to eq('Submitted for review')

        audit_log.action = 'approve'
        expect(audit_log.action_description).to eq('Approved')

        audit_log.action = 'reject'
        expect(audit_log.action_description).to eq('Rejected')

        audit_log.action = 'suspend'
        expect(audit_log.action_description).to eq('Suspended')

        audit_log.action = 'publish'
        expect(audit_log.action_description).to eq('Published')

        audit_log.action = 'unpublish'
        expect(audit_log.action_description).to eq('Unpublished')
      end
    end

    describe '#changed_fields_display' do
      it 'returns readable list of changed fields' do
        audit_log.changed_fields = { 'name' => [ 'Old', 'New' ] }
        expect(audit_log.changed_fields_display).to eq('Name')

        audit_log.changed_fields = { 'name' => [ 'Old', 'New' ], 'email' => [ 'old@test.com', 'new@test.com' ] }
        expect(audit_log.changed_fields_display).to eq('Name and Email')

        audit_log.changed_fields = {
          'name' => [ 'Old', 'New' ],
          'email' => [ 'old@test.com', 'new@test.com' ],
          'phone' => [ '123', '456' ]
        }
        expect(audit_log.changed_fields_display).to eq('Name, Email, and Phone')
      end

      it 'returns message when no fields changed' do
        audit_log.changed_fields = {}
        expect(audit_log.changed_fields_display).to eq('No changes recorded')
      end
    end

    describe '#change_summary' do
      it 'returns summary of changes' do
        audit_log.action = 'update'
        audit_log.changed_fields = { 'name' => [ 'Old', 'New' ] }
        expect(audit_log.change_summary).to eq('Updated name')

        audit_log.action = 'create'
        audit_log.changed_fields = {}
        expect(audit_log.change_summary).to eq('Created school')
      end
    end

    describe '#significant_change?' do
      it 'returns true for significant actions' do
        %w[create delete submit approve reject suspend publish unpublish].each do |action|
          audit_log.action = action
          expect(audit_log.significant_change?).to be true
        end
      end

      it 'returns false for timestamp-only updates' do
        audit_log.action = 'update'
        audit_log.changed_fields = { 'updated_at' => [ 1.hour.ago, Time.current ] }
        expect(audit_log.significant_change?).to be false
      end

      it 'returns true for non-timestamp updates' do
        audit_log.action = 'update'
        audit_log.changed_fields = { 'name' => [ 'Old', 'New' ], 'updated_at' => [ 1.hour.ago, Time.current ] }
        expect(audit_log.significant_change?).to be true
      end
    end

    describe '#previous_value' do
      it 'returns previous value for field' do
        audit_log.changed_fields = { 'name' => [ 'Old Name', 'New Name' ] }
        expect(audit_log.previous_value('name')).to eq('Old Name')
      end

      it 'returns nil for non-existent field' do
        audit_log.changed_fields = {}
        expect(audit_log.previous_value('name')).to be_nil
      end
    end

    describe '#new_value' do
      it 'returns new value for field' do
        audit_log.changed_fields = { 'name' => [ 'Old Name', 'New Name' ] }
        expect(audit_log.new_value('name')).to eq('New Name')
      end

      it 'returns nil for non-existent field' do
        audit_log.changed_fields = {}
        expect(audit_log.new_value('name')).to be_nil
      end
    end

    describe '#time_ago' do
      it 'returns time in appropriate units' do
        audit_log.created_at = 30.seconds.ago
        expect(audit_log.time_ago).to match(/\d+ seconds ago/)

        audit_log.created_at = 5.minutes.ago
        expect(audit_log.time_ago).to match(/\d+ minutes ago/)

        audit_log.created_at = 2.hours.ago
        expect(audit_log.time_ago).to match(/\d+ hours ago/)

        audit_log.created_at = 3.days.ago
        expect(audit_log.time_ago).to match(/\d+ days ago/)
      end
    end
  end

  describe 'class methods' do
    describe '.create_for_record' do
      it 'creates audit log for record' do
        expect {
          AuditLog.create_for_record(school, 'update', user.id, { 'name' => [ 'Old', 'New' ] })
        }.to change(AuditLog, :count).by(1)

        log = AuditLog.last
        expect(log.auditable).to eq(school)
        expect(log.user_id).to eq(user.id)
        expect(log.action).to eq('update')
        expect(log.changed_fields).to eq({ 'name' => [ 'Old', 'New' ] })
      end

      it 'handles array of field names' do
        school.name = 'New Name'
        school.save!

        AuditLog.create_for_record(school, 'update', user.id, [ 'name' ])

        log = AuditLog.last
        expect(log.changed_fields.keys).to include('name')
      end

      it 'skips creation when no changes and not significant action' do
        expect {
          AuditLog.create_for_record(school, 'update', user.id, {})
        }.not_to change(AuditLog, :count)
      end

      it 'creates log for significant actions even without changes' do
        expect {
          AuditLog.create_for_record(school, 'approve', user.id, {})
        }.to change(AuditLog, :count).by(1)
      end

      it 'excludes timestamps by default' do
        changes = { 'name' => [ 'Old', 'New' ], 'updated_at' => [ 1.hour.ago, Time.current ] }
        AuditLog.create_for_record(school, 'update', user.id, [ 'name', 'updated_at' ])

        log = AuditLog.last
        expect(log.changed_fields.keys).not_to include('updated_at')
      end
    end
  end

  describe 'factory' do
    it 'creates valid audit log' do
      log = build(:audit_log, auditable: school)
      expect(log).to be_valid
    end
  end
end
