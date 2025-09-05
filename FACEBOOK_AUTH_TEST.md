# Facebook Authentication Test Guide

This guide helps you verify that the Facebook authentication requirement is working correctly for both contact forms.

## Manual Testing Steps

### 1. Test Without Facebook Authentication

1. **Open a school page** (e.g., `/schools/australian-international-school-bangkok-soi-20-campus`)
2. **Ensure you're not logged in** or logged in without Facebook
   - If logged in, sign out first
3. **Try the main contact form** (on the right side of the page)
   - Fill out the form fields
   - Should show "Continue with Facebook to Send Message" button
   - Should NOT show direct "Send Message" button
4. **Try the modal contact form** (click any "Contact School" button)
   - Fill out the form fields  
   - Should show "Continue with Facebook to Send Message" button
   - Should NOT show direct "Send Message" button

### 2. Test Facebook Authentication Required

1. **Click the Facebook login button** in either form
2. **Should redirect to Facebook OAuth** (or mock in development)
3. **After authentication**, should return to school page
4. **Form should now show** direct "Send Message" buttons
5. **Should be able to submit** inquiry successfully

### 3. Test Server-Side Protection

You can also test the server-side authentication by making direct requests:

```bash
# Test without authentication (should fail with 401/403)
curl -X POST http://localhost:3000/schools/1/school_inquiries \
  -H "Content-Type: application/json" \
  -d '{"school_inquiry": {"name": "Test", "email": "test@test.com", "message": "Test", "children_count": 1}}'

# Should return error about Facebook authentication required
```

## What Should Happen

### ✅ **Correct Behavior:**
1. **Unauthenticated users** see Facebook login requirements in both forms
2. **Non-Facebook users** (regular email signup) also see Facebook requirements
3. **Facebook-authenticated users** can submit inquiries directly
4. **Server rejects** any attempts to bypass authentication
5. **Forms preserve data** during Facebook OAuth flow
6. **Modal restores form data** after authentication

### ❌ **Incorrect Behavior (Fixed):**
- ~~Users can submit inquiries without Facebook authentication~~
- ~~Modal form bypasses authentication checks~~
- ~~Direct server requests succeed without authentication~~

## Verification Checklist

- [ ] Main contact form requires Facebook authentication
- [ ] Modal contact form requires Facebook authentication  
- [ ] Facebook login button redirects properly
- [ ] Forms show correct buttons based on auth status
- [ ] Server-side controller blocks unauthenticated requests
- [ ] Form data is preserved during OAuth flow
- [ ] Success message appears after successful submission

## Development vs Production

### Development Mode
- Uses mock Facebook authentication (`/users/auth/facebook/mock`)
- Creates test user "Benjamin Fauchald"
- No actual Facebook API calls required

### Production Mode  
- Uses real Facebook OAuth (`/users/auth/facebook`)
- Requires valid Facebook app credentials
- Users must have real Facebook accounts

## Common Issues & Solutions

### Issue: Modal still allows submission without Facebook
**Solution:** Check that JavaScript controller values are properly set in HTML

### Issue: Facebook login doesn't redirect back properly  
**Solution:** Verify `FACEBOOK_REDIRECT_URI` matches configured webhook URLs

### Issue: Form data is lost after Facebook login
**Solution:** Check that `sessionStorage` is working and `restoreFormData()` is called

### Issue: Server still accepts unauthenticated requests
**Solution:** Verify `SchoolInquiriesController` has `require_facebook_authentication!` filter

## Files Modified for Facebook Authentication

### Controllers
- `SchoolInquiriesController` - Server-side authentication checks
- `Users::OmniauthCallbacksController` - OAuth handling

### Views  
- `schools/show.html.erb` - Modal form with Facebook auth UI
- `schools/contact_form_component.html.erb` - Main form with Facebook auth

### JavaScript
- `school_contact_modal_controller.js` - Modal authentication logic
- `school_contact_form_controller.js` - Main form authentication logic

### Routes
- Facebook OAuth routes already configured
- School inquiry routes protected by authentication

This comprehensive authentication system ensures that only verified Facebook users can send school inquiries, preventing spam while maintaining a good user experience.