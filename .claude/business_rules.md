# Business Rules Documentation

## Core Business Rules

## Business Rule: User Authentication & Roles
- Users can authenticate via email/password or Facebook OAuth
- Two role types: `school_owner` and `admin`
- School owners can only manage schools they have approved claims for
- Admins have full access to all schools and system functions
- Facebook users skip email confirmation on registration
- Facebook authentication required for submitting school inquiries
- Users created via OAuth get default role of `school_owner`

## Business Rule: School Inquiry Requirements
- **Must be signed in**: Anonymous users cannot submit inquiries
- **Must be Facebook authenticated**: Regular email users cannot submit inquiries
- **Required fields**: name, email, message, children_count
- **Validation limits**:
  - Name: maximum 100 characters
  - Email: valid email format
  - Message: maximum 2000 characters  
  - Children count: 1-20
  - Phone: maximum 20 characters (optional)
- **IP tracking**: System records IP address for all inquiries
- **User association**: Inquiries always linked to authenticated user
- **Lead source tracking**: "Facebook: [Name]" for Facebook users

## Business Rule: School Ownership Claims
- One pending or approved claim per user-school combination
- Claims have four statuses: `pending`, `approved`, `rejected`, `revoked`
- Evidence URL must be valid HTTP/HTTPS URL
- Notes limited to 1000 characters
- Approved claims grant school management access
- Revoked claims can include revocation reason
- Claims older than 30 days considered "stale"
- Email notifications sent for all status changes
- Temp claims expire after registration

## Business Rule: School Publishing Status
- Schools have four statuses: `draft`, `pending_review`, `published`, `suspended`
- Only published schools appear in public listings
- Status transitions controlled by admin users
- Suspended schools hidden from public view
- Draft schools only visible to owners and admins

## Business Rule: School Data Validation
- **Required fields**: name, slug
- **Slug uniqueness**: Must be unique across all schools
- **Auto-slug generation**: Creates from name if not provided
- **Email validation**: Must be valid format if provided
- **Country codes**: Limited to TH, US, GB, SG, MY, JP, KR, CN
- **Ownership types**: nonprofit, private, foundation, other
- **Coordinates sync**: Updates geography when lat/lng changes
- **Place sync**: Updates coordinates from associated Place

## Business Rule: Facebook Data Deletion (GDPR)
- User account never deleted, only OAuth data removed
- Removes: provider, uid, facebook_name, facebook_profile_picture_url
- Preserves: email, school claims, inquiries, all business data
- User can no longer authenticate via Facebook after deletion
- Must provide confirmation URL to Facebook webhook
- Process must complete within Facebook's timeout requirements

## Business Rule: Location-Based Filtering
- Default search radius: 50km
- Location stored in cookies: home_lat, home_lng, radius
- Can bypass with `show_all=true` parameter
- Distance calculated using Haversine formula
- Schools must have valid coordinates for distance filtering
- Falls back to showing all schools if location unavailable

## Business Rule: Media Management
- Photos can be from Google Places or school uploads
- School owners can toggle visibility of individual photos
- YouTube videos fetched from configured channel URL
- Video visibility can be toggled individually
- Transcripts can be generated for YouTube videos
- Media items ordered by position/date

## Business Rule: Taxonomy System
- Terms organized under Vocabularies (curriculum, facility, language, etc.)
- Terms have unique slugs within vocabulary
- Taggings link terms to schools with optional date ranges
- Current terms filtered by valid_from/valid_to dates
- Multiple terms per category allowed
- Context derived from vocabulary code

## Business Rule: Fee Schedule Management
- Multiple fee schedules per school allowed
- Each schedule has academic year and grade level
- Tuition fees stored in THB
- Additional fees tracked separately
- Published status controls visibility
- Current schedule determined by most recent academic year

## Business Rule: Access Control Rules
- **School Owners**:
  - Can only edit schools with approved claims
  - Cannot approve/reject their own claims
  - Can view inquiries for owned schools only
  - Cannot access admin functions
- **Admins**:
  - Full access to all schools
  - Can approve/reject/revoke claims
  - Can view all inquiries system-wide
  - Can manage users and system settings
- **Anonymous Users**:
  - Can view published schools only
  - Can submit claims (creates account)
  - Cannot submit inquiries
  - Cannot access owner/admin areas

## Business Rule: Email Verification
- Required for email/password registration
- Skipped for Facebook OAuth users
- Temp claims processed on email confirmation
- Unconfirmed users cannot access protected features
- Confirmation tokens expire after standard Devise timeout

## Business Rule: Inquiry Status Workflow
- New inquiries start with status: `new`
- Status progression: new → read → responded → closed
- "Read" status auto-set when viewed by school owner
- Read timestamp tracked separately from status
- Inquiries cannot go backward in status
- Closed inquiries considered resolved

## Business Rule: Data Integrity Constraints
- School claims cannot reference non-existent schools
- Inquiries cannot be created without valid school
- User ID cannot be overridden via parameters
- School ID set by controller, not user input
- Temp claims linked by email to user accounts
- Orphaned records cleaned up in background

## Business Rule: Content Publishing
- Pages have statuses: draft, published
- Only published pages visible publicly
- Pages belong to single school
- SEO metadata optional but recommended
- Content can be AI-generated with approval
- Pages ordered by position or creation date

## Business Rule: API Rate Limiting
- No hard rate limits currently implemented
- Multiple inquiries from same user allowed
- Relies on Facebook authentication as spam prevention
- IP addresses logged for abuse detection
- System allows batch operations for admins

## Validation Rules

### School Model Validations
- `name`: required, no length limit
- `slug`: required, unique, auto-generated from name
- `email`: valid format, optional
- `status`: must be in [draft, pending_review, published, suspended]
- `ownership`: must be in [nonprofit, private, foundation, other], optional
- `country_code`: must be in [TH, US, GB, SG, MY, JP, KR, CN], optional

### User Model Validations
- `email`: required, unique (case-insensitive)
- `role`: must be in [school_owner, admin]
- `provider` and `uid`: required together for OAuth users

### SchoolInquiry Validations
- `name`: required, max 100 characters
- `email`: required, valid format
- `message`: required, max 2000 characters
- `children_count`: required, 1-20
- `phone`: optional, max 20 characters
- `status`: must be in [new, read, responded, closed]

### SchoolClaim Validations
- `school_id + user_id`: unique combination
- `status`: must be in [pending, approved, rejected, revoked]
- `evidence_url`: valid URL format, optional
- `notes`: max 1000 characters, optional

## Testing Coverage Analysis

### Well-Tested Business Rules
- User role permissions and access control
- School inquiry validation and Facebook requirement
- School claim uniqueness and status transitions
- School slug generation and uniqueness
- OAuth user creation and linking
- Validation limits and formats
- Location-based distance calculations

### Business Rules Potentially Missing Tests
- Complete GDPR deletion workflow with Facebook webhooks
- Stale claim identification (30-day rule)
- Temp claim to real claim conversion edge cases
- Media visibility toggle persistence
- YouTube transcript generation rules
- AI content generation approval workflow
- Concurrent claim submission handling
- Full taxonomy system with date ranges
- Fee schedule publishing rules
- Page SEO metadata requirements
- Audit log creation for all actions
- Background job error recovery
- Cache invalidation rules
- Multi-language validation rules

## Critical Business Constraints

### Data Protection
- Never delete user accounts via API
- Always preserve business relationships
- OAuth data removal must be reversible
- Audit all administrative actions

### Lead Quality
- Facebook authentication ensures real identity
- IP tracking prevents abuse
- Email verification for direct signups
- One inquiry per user per session recommended

### School Data Integrity  
- Published schools must have complete information
- Coordinates required for map display
- At least one photo recommended
- Contact information should be verified

### Claim Verification
- Evidence URL should be verifiable
- Admin review required for all claims
- Revocation must include reason
- Email notifications mandatory

### Performance Considerations
- Distance calculations cached where possible
- Photo visibility settings stored as JSON
- Taxonomy queries optimized with joins
- Background jobs for heavy operations