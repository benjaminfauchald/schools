# Hotjar Setup Guide

## Quick Setup

1. **Sign up for Hotjar**
   - Go to https://www.hotjar.com
   - Create a free account (35 daily sessions free)
   - Add your website URL

2. **Get your Site ID**
   - After creating your site in Hotjar, you'll see your Site ID
   - It's a 6-7 digit number (e.g., 3456789)

3. **Add to your .env file**
   ```bash
   HOTJAR_SITE_ID=3456789
   ```

4. **Restart your Rails server**
   ```bash
   # Ctrl+C to stop, then:
   bin/dev
   ```

## What's Tracked

### Session Recordings
- Full user sessions with mouse movements
- Clicks, scrolls, and form interactions
- Anonymized sensitive data

### Heatmaps (Enable in Hotjar Dashboard)
- Click heatmaps - where users click most
- Move heatmaps - where cursors hover
- Scroll heatmaps - how far users scroll

### Key Events We Track
- `location_set` - When user sets their location
- `school_viewed` - When a school page is viewed
- `inquiry_sent` - When contact form is submitted
- `filter_used` - When search filters are applied

### User Identification
- Users are identified as `user_123` (ID only, no PII)
- Tagged with user type (school_owner, admin)
- Area tags added to recordings for geographic insights

## Viewing Data

1. **Session Recordings**
   - Go to Hotjar Dashboard > Recordings
   - Filter by events, tags, or user properties
   - Watch exactly how users interact with your site

2. **Heatmaps**
   - Go to Heatmaps > Create New
   - Select pages to track (e.g., /schools/*)
   - Wait for data to accumulate (100+ pageviews)

3. **Conversion Funnels**
   - Track: Visit → Set Location → View School → Send Inquiry
   - Identify where users drop off

## Privacy & GDPR

- Hotjar automatically masks sensitive data (emails, phones, passwords)
- IP addresses are anonymized
- Users can opt-out at https://www.hotjar.com/policies/do-not-track
- Cookie consent handled automatically

## Useful Filters

In Hotjar Recordings, filter by:
- **Event**: `inquiry_sent` - See successful conversions
- **Event**: `location_set` - Watch onboarding flow
- **Tag**: Area names - See users from specific locations
- **User Property**: `user_type:school_owner` - School owners only

## Integration with Mixpanel

Both tools work together:
- **Mixpanel**: Quantitative data (numbers, trends)
- **Hotjar**: Qualitative data (why, how, user behavior)
- Use Mixpanel to find problems, Hotjar to understand them

## Troubleshooting

**Not seeing recordings?**
- Check HOTJAR_SITE_ID is set in .env
- Verify Site ID matches Hotjar dashboard
- Wait 5-10 minutes for first recordings
- Check browser console for errors

**Missing heatmap data?**
- Need 100+ pageviews to generate
- Enable heatmap for specific URL patterns
- Check date range in dashboard