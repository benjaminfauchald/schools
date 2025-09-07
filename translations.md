# AI Coder Translation Rules

## Overview
When working with translation files (typically YAML format), follow these strict formatting and structure requirements to ensure consistency and maintainability.

## Format Requirements

### 1. File Structure
- Use YAML format with proper indentation (2 spaces per level)
- Start with language code (e.g., `en:`)
- Use nested structure to organize translations logically

### 2. Key Naming Convention
- Use snake_case for all translation keys
- Keys should be the full english sentence
- Use underscores to separate words in keys
- Example: `Hello_world`, `Back_to_schools`, `Sign_up_to_claim`

### 3. Value Format
- Always use double quotes around translation values
- Use the complete English sentence as the value
- Make translations easily searchable in source code
- Ensure English speakers can understand the context even if they don't know the target language

### 4. Variable Handling
- Preserve variable placeholders exactly as they appear in the source
- Use the format `%{variable_name}` for interpolation
- Common variables include: `%{school_name}`, `%{contact}`, `%{user_name}`, etc.
- Do not modify variable names or format

### 5. Nesting Structure
- Group related translations under logical parent keys
- Common parent keys include:
  - `admin:` for text in the admin panel (use sub sections like admin.login.log_in, admin.login.email, admin.login.password, etc.)
  - `school_owner:` for text in the school owner panel (use sub sections like school_owner.login.log_in, school_owner.login.email, school_owner.login.password, etc.)
  - `app:` for application-wide text
  - `navigation:` for menu and navigation items
  - `forms:` for form labels and messages
  - `errors:` for error messages
  - `notifications:` for user notifications


## Example Structure

```yaml
en:
    Hello_world: "Hello world"
    
    app:
      Name: "Schools"
    
    navigation:
      Settings: "Settings"
      Back_to_schools: "Back to Schools"
      Sign_up_to_claim: "Sign Up to Claim"
      Claim_this_school: "Claim This School"
      Get_in_touch_directly_with_school_name: "Get in touch directly with %{school_name}"
      Find_school_name: "Find %{school_name}"
      Talk_to_contact: "Talk to %{contact}"
    
    forms:
      Submit_button: "Submit"
      Cancel_button: "Cancel"
      Required_field: "This field is required"
    
    errors:
      Page_not_found: "Page not found"
      Access_denied: "Access denied"
```

## Best Practices

### 1. Consistency
- Maintain the same key structure across all language files
- Use consistent naming patterns throughout the project
- Keep variable names identical across all translations

### 2. Searchability
- Keys should be easily searchable in source code
- Use descriptive names that indicate the content
- Avoid abbreviations that might be unclear

### 3. Maintainability
- Group related translations together
- Use logical nesting to avoid key conflicts
- Comment complex sections when necessary

### 4. Variable Safety
- Never modify variable placeholders during translation
- Ensure all variables from the source appear in translations
- Test that variables render correctly in the target language

## Common Mistakes to Avoid

1. **Incorrect key format**: Using camelCase or kebab-case instead of snake_case
2. **Missing quotes**: Not wrapping values in double quotes
3. **Variable modification**: Changing `%{school_name}` to `%{nom_ecole}` in French
4. **Inconsistent nesting**: Different structure between language files
5. **Incomplete sentences**: Using partial phrases instead of complete, contextual sentences

## Validation Checklist

Before submitting translation files, verify:
- [ ] All keys use snake_case format
- [ ] All values are wrapped in double quotes
- [ ] Variable placeholders are preserved exactly
- [ ] Nesting structure matches the source file
- [ ] Translations are complete sentences with context
- [ ] No syntax errors in YAML format
- [ ] Keys are descriptive and searchable