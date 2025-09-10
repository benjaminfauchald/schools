# RSpec Testing Requirements and Analysis

## Objective
Run all RSpec tests, fix failures, identify repeating patterns in failures, and document common issues to prevent future test mistakes.

## Requirements

### 1. Test Execution and Analysis
- Run complete RSpec test suite: `bundle exec rspec`
- Capture all test failures with detailed output
- Fix all failing tests to achieve 100% pass rate
- Document the fixing process and patterns identified

### 2. Pattern Recognition and Documentation
- Identify recurring failure patterns across multiple tests
- Categorize common failure types and their root causes
- Document these patterns in `testing.md` for future reference
- Create prevention guidelines based on identified patterns

### 3. Deliverables

#### A. Fixed Test Suite
- All RSpec tests must pass
- No pending or skipped tests without justification
- Clear, descriptive test names and descriptions

#### B. Testing.md Documentation File
Must include the following sections:

##### Common Test Failure Patterns
Document patterns like:
- **Database State Issues**
  - Tests not cleaning up properly
  - Shared state between tests
  - Factory/fixture conflicts
  - Database state not properly reset
  - Testing private viewcomponent methods
  - Testing private methods
  

- **Timing and Async Issues**
  - Race conditions in tests
  - Insufficient wait times for async operations
  - Order-dependent test failures

- **Mock and Stub Problems**
  - Over-mocking leading to brittle tests
  - Inconsistent mock setups
  - Missing stub cleanup

- **Environment Dependencies**
  - Hard-coded values
  - External service dependencies
  - Configuration-dependent failures

##### Specific Recurring Issues Found
For each identified pattern, document:
```markdown
## Issue: [Brief Description]
**Frequency:** [How many tests affected]
**Symptoms:** [What the failure looks like]
**Root Cause:** [Why it happens]
**Fix Applied:** [How it was resolved]
**Prevention:** [How to avoid in future tests]

### Example:
```ruby
# Bad - leads to state leakage
it "creates a user" do
  User.create!(name: "Test User")
  expect(User.count).to eq(1)
end

# Good - properly isolated
it "creates a user" do
  expect { User.create!(name: "Test User") }.to change(User, :count).by(1)
end
```

##### Test Writing Guidelines
Based on patterns found, create guidelines such as:
- Always use database cleaner or proper cleanup
- Use `let` and `let!` appropriately
- Avoid hardcoded dates and times
- Use proper factories instead of fixtures when possible
- Test behavior, not implementation details

##### Code Review Checklist
Create a checklist for reviewing new tests:
- [ ] Tests are isolated and don't depend on order
- [ ] Database state is properly managed
- [ ] No hardcoded values that could break in different environments
- [ ] Appropriate use of mocks/stubs
- [ ] Clear and descriptive test descriptions
- [ ] Tests follow established patterns from this document

## Implementation Steps

### Step 1: Initial Test Run
```bash
# Run all tests and capture output
bundle exec rspec --format documentation --out rspec_initial_results.txt

# Run with failure details
bundle exec rspec --format failures --out rspec_failures.txt
```

### Step 2: Failure Analysis
- Group failures by error type/message
- Identify which failures share similar root causes
- Look for patterns in:
  - Error messages
  - Stack traces
  - Test setup/teardown issues
  - Data dependencies

### Step 3: Systematic Fixing
- Fix failures starting with the most common patterns
- Document each fix and the pattern it addresses
- Verify fixes don't break other tests
- Run tests after each fix to ensure progress

### Step 4: Pattern Documentation
- Create detailed entries in `testing.md` for each pattern
- Include code examples of both wrong and right approaches
- Add prevention strategies for each pattern type

### Step 5: Validation
```bash
# Final test run to confirm all pass
bundle exec rspec

# Run multiple times to check for flaky tests
for i in {1..5}; do bundle exec rspec; done
```

## Success Criteria
- [ ] All RSpec tests pass consistently
- [ ] `testing.md` file created with comprehensive pattern documentation
- [ ] At least 3 recurring patterns identified and documented
- [ ] Prevention guidelines established for each pattern
- [ ] Code examples provided for common mistakes and fixes
- [ ] Future test writing checklist created

## Maintenance
- Update `testing.md` whenever new patterns are discovered
- Reference this document during code reviews
- Regularly review and update prevention guidelines
- Share learnings with the development team

## Tools and Commands
```bash
# Run specific test files to isolate issues
bundle exec rspec spec/models/user_spec.rb

# Run tests with specific tags
bundle exec rspec --tag focus

# Generate coverage report
bundle exec rspec --format html --out coverage/index.html

# Check for flaky tests
bundle exec rspec --seed [specific-seed] --order random
```