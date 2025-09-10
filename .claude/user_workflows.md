# User Workflows Documentation

## Models Overview

### Core Models
- **School**: Central model for educational institutions with rich metadata, taxonomy support, and location data
- **User**: System users with roles (school_owner, admin) and Facebook OAuth integration
- **Place**: Location data integrated with Google Places API
- **SchoolInquiry**: Parent inquiries about schools (leads for school owners)
- **SchoolClaim**: User requests for administrative rights over school profiles
- **TempClaim**: Temporary claims for users who haven't registered yet
- **Page**: School-managed content pages (About Us, etc.)
- **MediaItem**: Photos and videos associated with places/schools
- **Term/Vocabulary/Tagging**: Taxonomy system for categorizing schools (curricula, facilities, languages)
- **SchoolFeeSchedule**: Tuition and fee information
- **SchoolGradeOffering**: Age ranges and grade levels offered

## User Workflows

## Location-Based School Discovery
1. User visits the homepage
2. System prompts for location permission or shows onboarding page
3. User provides location (via browser geolocation or manual input)
4. System stores location in cookies (home_lat, home_lng, radius)
5. System displays schools within specified radius (default 50km)
6. User can filter by distance, facilities, curricula, or search by name
7. User can click "show all" to bypass distance filtering

## School Detail Page Viewing
1. User clicks on a school from the listing
2. System loads comprehensive school information including:
   - Hero section with name, rating, key stats
   - Contact information (phone, email, website)
   - Photo gallery (Google Places and uploaded photos)
   - YouTube videos (if channel configured)
   - Academic programs (curricula, languages, accreditations)
   - Facilities organized by category
   - Tuition and fees by grade level
   - Grade offerings and age ranges
   - Published school pages
   - Interactive map with location
3. User can view all sections progressively loaded
4. Contact form displayed at bottom for inquiries

## Parent Inquiry Submission (Lead Generation)
1. Parent views school detail page
2. Scrolls to contact form section
3. If not signed in:
   - Sees Facebook authentication requirement message
   - Must click "Sign in with Facebook" button
4. After Facebook authentication:
   - Form shows with name, email, phone, message, children count fields
   - User fills out inquiry form
   - Submits form
5. System creates SchoolInquiry record
6. Email notification sent to school
7. Inquiry appears in school owner's dashboard
8. Lead source tracked as "Facebook: [User Name]"

## Facebook OAuth Authentication Flow
1. User clicks "Sign in with Facebook" 
2. System stores school context (if applicable)
3. Redirected to Facebook OAuth consent page
4. User approves permissions
5. Facebook redirects back with auth data
6. System finds or creates user account:
   - Links to existing user by email if found
   - Creates new user with Facebook data if not found
7. User marked as confirmed (skips email verification)
8. User redirected back to original context (school page)
9. Can now submit inquiries to schools

## School Ownership Claim - Direct Flow
1. Anonymous user visits school detail page
2. Clicks "Claim this school" button
3. Fills out claim form:
   - Email address
   - Evidence URL (website, social media)
   - Notes explaining ownership
4. System creates User account and SchoolClaim
5. Confirmation email sent to user
6. Admin notified of pending claim
7. User must confirm email to activate account
8. Admin reviews and approves/rejects claim
9. User notified of decision
10. If approved, user gains school management access

## School Ownership Claim - Temp Claim Flow
1. User submits claim before having an account
2. System creates TempClaim with token
3. Email sent with registration link
4. User clicks link and creates account
5. On email confirmation, temp claims converted to real claims
6. Claims enter pending review status
7. Admin approval workflow continues

## School Owner Dashboard Management
1. School owner signs in (Facebook or email/password)
2. Accesses /school_owner/dashboard
3. Views owned schools (approved claims only)
4. Can manage for each school:
   - View and respond to inquiries
   - Edit school information
   - Manage academic programs
   - Update facilities
   - Upload/delete photos
   - Manage YouTube videos
   - Generate transcripts for videos
   - Upload documents
   - Create/edit school pages
   - Use AI chat for content generation
5. Can view inquiry analytics and lead sources

## Admin School Claim Review
1. Admin signs in to /admin
2. Views pending school claims
3. Reviews evidence and notes
4. Can approve, reject, or revoke claims
5. Approval grants school_owner access
6. Rejection/revocation removes access
7. Users notified of status changes
8. Audit log created for all actions

## Facebook Data Deletion (GDPR Compliance)
1. User deletes app from Facebook settings
2. Facebook sends webhook to /facebook_webhooks/delete_data
3. System verifies webhook signature
4. Finds user by Facebook UID
5. Removes Facebook OAuth data:
   - Provider and UID cleared
   - Facebook name and profile picture removed
6. User account preserved for business continuity
7. School claims and inquiries remain intact
8. User can no longer sign in via Facebook
9. Confirmation URL returned to Facebook

## School Content Management
1. School owner accesses school edit page
2. Can create/edit pages (About Us, Mission, etc.)
3. Uses AI suggestions for content generation
4. Pages can be published or kept as drafts
5. Published pages appear on school detail page
6. Pages support rich text formatting
7. SEO metadata can be customized

## YouTube Video Management
1. School owner adds YouTube channel URL
2. System fetches videos from channel
3. Owner can toggle visibility of individual videos
4. Can generate transcripts for videos
5. Transcripts can be used for AI content
6. Videos display on school detail page
7. View counts and metadata tracked

## API Endpoints

## API: School Inquiry Submission
- **Endpoint**: POST /schools/:school_id/school_inquiries
- **Authentication**: Required (user must be signed in)
- **Facebook Required**: User must be Facebook authenticated
- **Success Response**: 200 OK with success message
- **Validation Error**: 422 with error details
- **Not Authenticated**: 401 Unauthorized
- **Not Facebook User**: 403 Forbidden
- **School Not Found**: 404 Not Found
- **Creates**: SchoolInquiry record with user association

## API: Direct Claim Creation
- **Endpoint**: POST /schools/:school_id/claim
- **Authentication**: Optional (creates account if needed)
- **Success Response**: 200 OK (JSON) or redirect (HTML)
- **Validation Error**: 422 with errors
- **Creates**: User account and SchoolClaim record
- **Email Verification**: Required for new accounts

## API: Location Validation
- **Endpoint**: POST /api/v1/location/validate
- **Purpose**: Validate and store user location
- **Parameters**: lat, lng, radius
- **Response**: Valid location data or error

## API: Facebook Sync Status
- **Endpoint**: POST /users/auth/facebook/sync_status
- **Purpose**: Check Facebook authentication status
- **Used by**: JavaScript to update UI dynamically
- **Response**: Authentication status and user data

## API: School Search
- **Endpoint**: GET /schools/search
- **Parameters**: query, lat, lng, radius
- **Response**: Filtered schools with distance calculations
- **Features**: Full-text search, distance filtering

## Data Flow

### Lead Generation Flow
```
User → School Detail Page → Contact Form → Facebook Auth Check
  ↓ (if not authenticated)
  → Facebook OAuth → User Creation/Link
  ↓ (if authenticated)
  → SchoolInquiry Creation → Email Notification → School Owner Dashboard
```

### School Claim Flow
```
Anonymous User → Claim Form → TempClaim/User Creation
  ↓
  → Email Confirmation → SchoolClaim Creation
  ↓
  → Admin Review → Approval/Rejection
  ↓
  → User Notification → School Access (if approved)
```

### Location-Based Discovery Flow
```
User Visit → Location Check (Cookie)
  ↓ (if no location)
  → Onboarding Page → Location Permission/Input
  ↓ (location stored)
  → School Listing (filtered by distance) → School Details
```

### Facebook Data Deletion Flow
```
Facebook Deletion Request → Webhook Verification
  ↓
  → User Lookup by UID → OAuth Data Removal
  ↓
  → User Account Preserved → Business Data Intact
  ↓
  → Confirmation URL to Facebook
```

## Testing Coverage Analysis

### Well-Tested Workflows
- School inquiry submission with Facebook authentication
- Direct claim creation and validation
- User authentication via Facebook OAuth
- School detail page rendering
- Location-based filtering
- Data validation and error handling

### Areas Potentially Missing Tests
- Complete Facebook data deletion webhook flow
- School owner dashboard all features (AI chat, document management)
- YouTube video transcript generation
- Page content generation with AI
- Bulk admin operations (bulk approve/reject claims)
- Media item upload and management
- Complete onboarding flow with various location input methods
- Magic link authentication flow
- Multi-language support (en/th locale switching)