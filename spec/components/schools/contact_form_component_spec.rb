require 'rails_helper'
require_relative '../../../app/components/schools/contact_form_component'

RSpec.describe Schools::ContactFormComponent, type: :component do
  around do |example|
    I18n.with_locale(:en) do
      example.run
    end
  end
  
  let(:school) { create(:school) }
  let(:contact_info) do
    {
      phone: '+66 2 123 4567',
      email: 'info@testschool.com',
      website: 'https://testschool.com'
    }
  end

  describe 'initialization' do
    it 'initializes with required parameters' do
      component = described_class.new(
        school: school,
        contact_info: contact_info,
        user_signed_in: false,
        facebook_authenticated: false
      )
      expect(component).to be_present
    end

    it 'creates a new SchoolInquiry instance' do
      component = described_class.new(
        school: school,
        contact_info: contact_info,
        user_signed_in: false,
        facebook_authenticated: false
      )
      expect(component.instance_variable_get(:@school_inquiry)).to be_a(SchoolInquiry)
    end

    it 'accepts debug_mode parameter' do
      component = described_class.new(
        school: school,
        contact_info: contact_info,
        user_signed_in: false,
        facebook_authenticated: false,
        debug_mode: true
      )
      expect(component.instance_variable_get(:@debug_mode)).to be true
    end
  end

  describe 'rendering' do
    subject(:rendered) do
      render_inline(described_class.new(
        school: school,
        contact_info: contact_info,
        user_signed_in: user_signed_in,
        facebook_authenticated: facebook_authenticated,
        debug_mode: false
      ))
    end

    context 'when user is not signed in' do
      let(:user_signed_in) { false }
      let(:facebook_authenticated) { false }

      it 'renders contact form' do
        expect(rendered.css('form')).to be_present
      end

      it 'displays authentication requirement message' do
        expect(rendered.text).to include('Please sign in with Facebook')
      end

      it 'shows Facebook authentication button instead of submit button' do
        expect(rendered.css('button[type="submit"]')).to be_empty
        expect(rendered.css('a').text).to include('Facebook')
      end

      it 'includes form fields' do
        expect(rendered.css('input[name="school_inquiry[name]"]')).to be_present
        expect(rendered.css('input[name="school_inquiry[email]"]')).to be_present
        expect(rendered.css('input[name="school_inquiry[phone]"]')).to be_present
        expect(rendered.css('input[name="school_inquiry[children_count]"]')).to be_present
        expect(rendered.css('textarea[name="school_inquiry[message]"]')).to be_present
      end

      it 'shows explanation about Facebook requirement' do
        expect(rendered.text).to include('Facebook')
      end
    end

    context 'when user is signed in but not Facebook authenticated' do
      let(:user_signed_in) { true }
      let(:facebook_authenticated) { false }

      it 'shows Facebook authentication requirement' do
        expect(rendered.text).to include('Please sign in with Facebook')
      end

      it 'does not show direct submit button' do
        expect(rendered.css('input[type="submit"][value="Send Message"]')).to be_empty
      end
    end

    context 'when user is Facebook authenticated' do
      let(:user_signed_in) { true }
      let(:facebook_authenticated) { true }

      it 'renders contact form with submit button' do
        expect(rendered.css('form')).to be_present
        expect(rendered.css('input[type="submit"]')).to be_present
      end

      it 'shows encouragement message' do
        expect(rendered.text).to include(school.name)
      end

      it 'does not show Facebook authentication requirement' do
        expect(rendered.text).not_to include('Please sign in with Facebook')
      end
    end

    context 'form field attributes' do
      let(:user_signed_in) { true }
      let(:facebook_authenticated) { true }

      it 'sets correct form attributes' do
        form = rendered.css('form').first
        expect(form['method']).to eq('post')
        expect(form['novalidate']).to eq('novalidate')
      end

      it 'includes required form fields with proper attributes' do
        # Name field
        name_field = rendered.css('input[name="school_inquiry[name]"]').first
        expect(name_field['required']).to eq('required')
        expect(name_field['placeholder']).to be_present

        # Email field
        email_field = rendered.css('input[name="school_inquiry[email]"]').first
        expect(email_field['type']).to eq('email')
        expect(email_field['required']).to eq('required')
        expect(email_field['placeholder']).to be_present

        # Phone field (optional)
        phone_field = rendered.css('input[name="school_inquiry[phone]"]').first
        expect(phone_field['type']).to eq('tel')
        expect(phone_field['required']).to be_nil

        # Children count field
        children_field = rendered.css('input[name="school_inquiry[children_count]"]').first
        expect(children_field['type']).to eq('number')
        expect(children_field['min']).to eq('1')
        expect(children_field['max']).to eq('20')
        expect(children_field['value']).to eq('1')
        expect(children_field['required']).to eq('required')

        # Message field
        message_field = rendered.css('textarea[name="school_inquiry[message]"]').first
        expect(message_field['required']).to eq('required')
        expect(message_field['rows']).to eq('4')
        expect(message_field['maxlength']).to eq('2000')
      end

      it 'includes proper form styling classes' do
        input_field = rendered.css('input[name="school_inquiry[name]"]').first
        expect(input_field['class']).to include('border-gray-300')
        expect(input_field['class']).to include('rounded-md')
        expect(input_field['class']).to include('focus:ring-blue-500')
      end
    end
  end

  describe 'render behavior' do
    it 'renders when school is present' do
      component = described_class.new(
        school: school,
        contact_info: contact_info,
        user_signed_in: false,
        facebook_authenticated: false
      )
      rendered = render_inline(component)
      expect(rendered.to_html.strip).not_to be_empty
    end

    it 'does not render when school is nil' do
      component = described_class.new(
        school: nil,
        contact_info: contact_info,
        user_signed_in: false,
        facebook_authenticated: false
      )
      rendered = render_inline(component)
      expect(rendered.to_html.strip).to be_empty
    end
  end

  describe 'Stimulus data attributes' do
    subject(:rendered) do
      render_inline(described_class.new(
        school: school,
        contact_info: contact_info,
        user_signed_in: true,
        facebook_authenticated: true
      ))
    end

    it 'includes Stimulus controller data attributes' do
      form = rendered.css('form').first
      expect(form['data-school-contact-form-target']).to eq('form')
      expect(form['data-action']).to include('submit->school-contact-form#submitForm')
    end

    it 'includes submit button target' do
      submit_button = rendered.css('input[type="submit"]').first
      expect(submit_button['data-school-contact-form-target']).to eq('submitButton')
    end
  end

  describe 'with different contact info' do
    let(:extended_contact_info) do
      {
        phone: '+66 2 123 4567',
        email: 'contact@school.com',
        website: 'https://school.com',
        address: '123 School Street, Bangkok'
      }
    end

    subject(:rendered) do
      render_inline(described_class.new(
        school: school,
        contact_info: extended_contact_info,
        user_signed_in: true,
        facebook_authenticated: true
      ))
    end

    it 'renders successfully with extended contact info' do
      expect(rendered.css('form')).to be_present
    end
  end

  describe 'accessibility features' do
    subject(:rendered) do
      render_inline(described_class.new(
        school: school,
        contact_info: contact_info,
        user_signed_in: true,
        facebook_authenticated: true
      ))
    end

    it 'includes proper form labels' do
      expect(rendered.css('label[for="school_inquiry_name"]')).to be_present
      expect(rendered.css('label[for="school_inquiry_email"]')).to be_present
      expect(rendered.css('label[for="school_inquiry_children_count"]')).to be_present
      expect(rendered.css('label[for="school_inquiry_message"]')).to be_present
    end

    it 'associates labels with form fields' do
      name_label = rendered.css('label[for="school_inquiry_name"]').first
      expect(name_label).to be_present

      email_label = rendered.css('label[for="school_inquiry_email"]').first
      expect(email_label).to be_present
    end

    it 'includes placeholder text for user guidance' do
      message_field = rendered.css('textarea[name="school_inquiry[message]"]').first
      expect(message_field['placeholder']).to be_present
    end
  end

  describe 'debug mode' do
    subject(:rendered) do
      render_inline(described_class.new(
        school: school,
        contact_info: contact_info,
        user_signed_in: true,
        facebook_authenticated: true,
        debug_mode: true
      ))
    end

    it 'renders successfully in debug mode' do
      expect(rendered.css('form')).to be_present
    end
  end
end
