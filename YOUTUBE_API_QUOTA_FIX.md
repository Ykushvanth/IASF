# YouTube API 403 Error Fix Guide

## Problem
Your app is showing "YouTube API error: 403" when trying to fetch videos. This means:
- ❌ YouTube API daily quota exceeded (10,000 units/day for free tier)
- ❌ API key doesn't have proper permissions
- ❌ API key is restricted

## Current API Key Status
Your API key in `lib/config/api_keys.dart`: `AIzaSyCYwCbWR53z4buyJ2lnEdHp_P5WLTAZa1M`

## Solutions

### Solution 1: Wait for Quota Reset (Easiest)
YouTube API quota resets daily at **midnight Pacific Time (PST/PDT)**

**What to do:**
1. Wait until tomorrow (after midnight Pacific Time)
2. Your quota will automatically reset to 10,000 units
3. App will work normally again

**Quota Usage:**
- Each video search = ~100 units
- Each video details fetch = ~1 unit
- With 21 days × 3 videos = ~2,100 units per roadmap
- Free tier = 10,000 units/day (can create ~4-5 roadmaps per day)

---

### Solution 2: Check API Key Permissions
Your API key might not have YouTube Data API v3 enabled.

**Steps:**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Go to **APIs & Services → Library**
4. Search for "YouTube Data API v3"
5. Click on it and make sure it says **"API Enabled"** (green)
6. If not, click **"Enable"** button

---

### Solution 3: Check API Key Restrictions

**Steps:**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Go to **APIs & Services → Credentials**
3. Find your API key: `AIzaSyCYwCbWR53z4buyJ2lnEdHp_P5WLTAZa1M`
4. Click on it to edit
5. Check **API restrictions**:
   - Should have "YouTube Data API v3" allowed
   - Remove any other restrictions if present
6. Check **Application restrictions**:
   - For testing, set to "None"
   - For production, add your app's package name
7. Save changes

---

### Solution 4: Get Additional Quota (For Heavy Usage)

If you need more than 10,000 units/day:

**Option A: Request Quota Increase (Free)**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Go to **APIs & Services → YouTube Data API v3**
3. Click **"Quotas"** tab
4. Click **"Request Quota Increase"**
5. Fill out the form explaining your use case
6. Wait for approval (usually 1-3 days)

**Option B: Billing Account (Paid)**
1. Enable billing in Google Cloud Console
2. Get 1 million quota units/day automatically
3. Charged beyond free tier: $0.25 per 10,000 units

---

### Solution 5: Create a New API Key

If your current key is problematic:

**Steps:**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project (or use existing)
3. Enable **YouTube Data API v3**
4. Go to **APIs & Services → Credentials**
5. Click **"Create Credentials" → "API Key"**
6. Copy the new API key
7. Update in `lib/config/api_keys.dart`:
   ```dart
   static const String youtubeApiKey = 'YOUR_NEW_API_KEY_HERE';
   ```

---

## App Behavior During Quota Issues

### What happens now:
- ✅ Roadmap still generates with topics
- ✅ Topics are specific and unique (Loops, Functions, etc.)
- ❌ Videos don't load during roadmap creation
- ✅ **Videos can be loaded later** when you open each topic

### Videos Load On-Demand:
1. Open your roadmap
2. Tap on any day/topic card
3. Videos will load when you open that specific topic
4. This uses much less quota (only loads when needed)

---

## Quick Verification Checklist

Run through this checklist:

- [ ] YouTube Data API v3 is **enabled** in your project
- [ ] API key has **no restrictions** (or only YouTube API allowed)
- [ ] Current date/time is **after midnight Pacific** (for quota reset)
- [ ] API key is **39 characters long** (yours is: 39 ✓)
- [ ] API key is **not expired** or revoked

---

## Check Your Quota Usage

See how much quota you've used:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Go to **APIs & Services → Dashboard**
4. Click on **YouTube Data API v3**
5. Click **"Quotas"** tab
6. You'll see:
   - **Queries per day**: Used / 10,000
   - **Resets at**: Midnight Pacific Time

---

## Temporary Workaround

While waiting for quota reset or approval:

### Option 1: Use Fewer Days
When creating roadmap, choose:
- Shorter duration (30 days instead of 90)
- This uses less quota

### Option 2: Skip Initial Video Load
The app already does this! Videos after day 21 are lazy-loaded:
- Only first 21 days fetch videos initially
- Rest load when you open them
- Saves quota

### Option 3: Manual Video Search
For now, you can:
1. Look at topic name (e.g., "Python - Loops and Iteration")
2. Search YouTube manually for that topic
3. Videos will work once quota resets

---

## Error Logs Explained

What you're seeing:
```
I/flutter: 🔍 Final search query: GATE Probability Theory tutorial
I/flutter: ❌ YouTube API error: 403
I/flutter: ⚠️ No videos found for: Probability Theory
```

This means:
- ✅ Search query is correct
- ✅ API call is made
- ❌ YouTube rejected it (quota/permission issue)
- ℹ️ Topics still created, just no videos yet

---

## Testing After Fix

After applying any solution:

1. **Clear app data** (optional, to force fresh fetch)
2. **Create a new roadmap**
3. **Check console logs**:
   - Should see: `✅ Found 3 videos for: [Topic Name]`
   - Should NOT see: `❌ YouTube API error: 403`

4. **Verify in UI**:
   - Expand any day card
   - Should see 3 video thumbnails
   - Videos should play when tapped

---

## Support

If none of these solutions work:

1. **Check API Key Format**: Must be 39 characters, starts with `AIza`
2. **Try Different API Key**: Create a fresh one
3. **Check Google Cloud Status**: [status.cloud.google.com](https://status.cloud.google.com)
4. **Review Logs**: Look for additional error details in console

---

## Summary

**Most Likely Cause**: Daily quota exceeded (10,000 units)

**Quickest Fix**: Wait until tomorrow (quota resets at midnight Pacific)

**Long-term Fix**: 
- Request quota increase (free, 1-3 days approval)
- OR enable billing (instant, but costs money for high usage)

**Your App Still Works**: Topics are created perfectly, videos just need quota to load!

---

## Quota-Friendly Best Practices

To avoid quota issues in future:

1. **Cache Videos**: Save fetched videos in Firebase (already doing this!)
2. **Lazy Load**: Load videos only when topic is opened (already doing this for day 22+!)
3. **Batch Requests**: Fetch multiple video details in one call (already doing this!)
4. **User Feedback**: Show helpful message when quota exceeded (just added!)

Your app already follows these best practices! The quota limit is just a YouTube restriction.
