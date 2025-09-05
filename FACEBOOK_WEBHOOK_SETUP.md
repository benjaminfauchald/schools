# Facebook Webhook Setup Guide

This guide explains how to configure Facebook webhooks for GDPR compliance and data management.

## Environment Variables Required

Add these environment variables to your `.env` file:

```bash
# Facebook OAuth (already configured)
FACEBOOK_APP_ID=714264194995841
FACEBOOK_APP_SECRET=3aab0e448a8cfdf730f5e5685ef462da

# Facebook Webhook Configuration (NEW - REQUIRED)
FACEBOOK_WEBHOOK_VERIFY_TOKEN=your_webhook_verify_token_here
```

## Facebook Developer Console Configuration

### 1. Webhook URLs to Configure

In your Facebook App settings at: https://developers.facebook.com/apps/714264194995841/

#### **Webhook Verify URL**
- **URL**: `https://listing.connectica.no/facebook_webhooks/verify`
- **Method**: GET
- **Purpose**: Facebook uses this to verify webhook endpoint

#### **Data Deletion Callback URL**
- **URL**: `https://listing.connectica.no/facebook_webhooks/delete_data`  
- **Method**: POST
- **Purpose**: Handle user data deletion requests (GDPR compliance)

#### **Deauthorization Callback URL**
- **URL**: `https://listing.connectica.no/facebook_webhooks/deauthorize`
- **Method**: POST  
- **Purpose**: Handle when users revoke app permissions

### 2. Legacy URL Support

For backward compatibility, the following URL also works:
- **URL**: `https://listing.connectica.no/delete_data`
- **Redirects to**: `/facebook_webhooks/delete_data`

## How It Works

### Data Deletion Flow
1. User requests data deletion from Facebook
2. Facebook sends POST request to `/facebook_webhooks/delete_data`
3. System validates request signature using `FACEBOOK_APP_SECRET`
4. User's Facebook OAuth data is removed from database
5. Audit log is created for compliance
6. Confirmation URL is returned to Facebook

### Deauthorization Flow  
1. User revokes app permissions in Facebook
2. Facebook sends POST request to `/facebook_webhooks/deauthorize`
3. System validates request signature
4. User's OAuth tokens are invalidated
5. User can no longer send school inquiries without re-authorization
6. Audit log is created

## Security Features

### Request Signature Validation
All webhook requests are validated using HMAC-SHA256 with your Facebook app secret:
- Invalid signatures are rejected with 401 status
- Security incidents are logged in audit trail
- No user data is modified for invalid requests

### Data Protection
- Only Facebook OAuth data is deleted, not user accounts
- Business records (school inquiries, claims) are preserved
- Complete audit trail maintained for compliance

### Error Handling
- Comprehensive error logging for troubleshooting
- Graceful handling of missing users
- Proper HTTP status codes for all scenarios

## Database Changes

### New Table: webhook_audit_logs
Tracks all webhook events for compliance:
- `webhook_type`: 'deletion' or 'deauthorization'
- `facebook_user_id`: Facebook user identifier
- `user_id`: Internal user ID (if found)
- `payload`: Full webhook payload from Facebook
- `status`: 'processed', 'failed', or 'invalid'
- `error_message`: Error details if processing failed
- `processed_at`: Timestamp of processing

### User Model Extensions
New methods added to User model:
- `delete_facebook_data!`: Removes OAuth data while preserving account
- `deauthorize_facebook!`: Removes authorization capability
- `facebook_webhook_deletable?`: Checks if deletion is allowed

## Testing Webhooks

### Development Environment
The webhook endpoints work in development, but will only accept requests with valid signatures.

### Manual Testing
You can test webhook signature validation using the Facebook Developer Console webhook testing tool.

### Audit Log Verification
Check webhook processing results:
```ruby
# In Rails console
WebhookAuditLog.recent.limit(10)
WebhookAuditLog.deletions.successful
WebhookAuditLog.deauthorizations.failed
```

## Deployment Checklist

- [ ] Set `FACEBOOK_WEBHOOK_VERIFY_TOKEN` in production environment
- [ ] Configure Facebook webhook URLs in Developer Console
- [ ] Test webhook verification endpoint
- [ ] Verify signature validation is working
- [ ] Monitor audit logs for proper webhook processing
- [ ] Confirm HTTPS is enabled for all webhook endpoints

## Troubleshooting

### Common Issues

**Webhook Verification Failed**
- Check `FACEBOOK_WEBHOOK_VERIFY_TOKEN` matches Facebook configuration
- Ensure endpoint is accessible via HTTPS
- Verify GET request works for verification URL

**Signature Validation Errors**  
- Confirm `FACEBOOK_APP_SECRET` is correctly set
- Check webhook payload is being received properly
- Verify Facebook is sending `X-Hub-Signature-256` header

**User Not Found Errors**
- This is normal - webhooks may reference deleted users
- Events are still logged for compliance
- No action required

### Log Files
Check Rails logs for webhook processing:
```bash
tail -f log/production.log | grep FacebookWebhook
```

## Compliance Notes

This implementation provides:
- ✅ GDPR-compliant data deletion
- ✅ Complete audit trail for all webhook events  
- ✅ Secure signature validation
- ✅ Proper error handling and logging
- ✅ User account preservation (business requirement)
- ✅ Facebook platform policy compliance