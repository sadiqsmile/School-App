# 🔒 Firebase Cloud Functions - Attendance Auto-Lock System

## 📋 Overview

This Cloud Functions setup provides **4 automated functions** for your attendance system:

1. ✅ **Auto-Lock Attendance** - Locks attendance at 4:00 PM daily
2. ✅ **Manual Unlock** - Admin can unlock locked attendance
3. ✅ **Monthly Summary Generator** - Auto-calculates monthly attendance %
4. ✅ **Low Attendance Alerts** - Sends notifications to parents

---

## 🚀 Quick Setup (5 Minutes)

### Step 1: Install Dependencies
```bash
cd functions
npm install
```

### Step 2: Deploy Functions
```bash
# Login to Firebase (if not already)
firebase login

# Deploy all functions
firebase deploy --only functions

# Or deploy specific function
firebase deploy --only functions:autoLockAttendance
```

### Step 3: Verify Deployment
```bash
# Check logs
firebase functions:log
```

---

## 📊 Function Details

### 1. Auto-Lock Attendance ⏰
**Schedule:** Every day at 4:00 PM (Asia/Kolkata)

**What it does:**
- Locks all attendance records for the current day
- Prevents teachers from editing after deadline
- Skips already locked records and holidays

**Firestore Path:**
```
schools/{schoolId}/attendance/{classSectionId}/days/{dateString}
  └─ meta.locked = true
  └─ meta.lockedAt = timestamp
  └─ meta.lockedBy = "system_auto_lock"
```

**Logs:**
```
Starting auto-lock for date: 2026-02-21
Found 3 schools
School school_001: Found 12 class-sections
Locked: school_001/5_A/2026-02-21
Auto-lock completed. Locked: 36, Skipped: 5
```

---

### 2. Manual Unlock 🔓
**Type:** Callable HTTPS Function (Admin Only)

**How to use from Flutter:**
```dart
import 'package:cloud_functions/cloud_functions.dart';

Future<void> unlockAttendance({
  required String schoolId,
  required String classSectionId,
  required String date,
}) async {
  try {
    final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
    final result = await functions.httpsCallable('unlockAttendance').call({
      'schoolId': schoolId,
      'classSectionId': classSectionId,
      'date': date, // Format: "2026-02-21"
    });
    
    print('Success: ${result.data['message']}');
  } catch (e) {
    print('Error: $e');
  }
}
```

**Security:**
- Requires authentication
- Verifies admin role
- Logs unlock action with admin UID

---

### 3. Monthly Summary Generator 📅
**Schedule:** 1st of every month at 1:00 AM

**What it does:**
- Calculates previous month's attendance for all students
- Generates percentage, present count, absent count
- Stores in `attendance_summary` collection

**Firestore Output:**
```
schools/{schoolId}/attendance_summary/{classSectionId}/months/{YYYY-MM}
  students:
    student_001:
      totalPresent: 22
      totalAbsent: 3
      percentage: 88.0
      studentName: "John Doe"
      rollNumber: "01"
```

**Example Log:**
```
Generating monthly summaries for: 2026-01
Summary generated for school_001/5_A/2026-01
Monthly summaries generation completed
```

---

### 4. Low Attendance Alerts 📢
**Schedule:** Every day at 8:00 PM

**What it does:**
- Checks monthly attendance percentages
- Sends FCM notification if below 75%
- Notifies parents via push notification

**Notification Format:**
```
Title: "Low Attendance Alert"
Body: "John Doe's attendance is 68.5% this month"
```

**Requirements:**
- Parent must have `fcmToken` in Firestore
- Student document must have `parentId` field

---

## 🛠️ Configuration

### Change Auto-Lock Time
**File:** `functions/index.js`

```javascript
// Line 13
.pubsub.schedule("0 16 * * *") // Change: 16 = 4 PM

// Examples:
"0 10 * * *"  // 10:00 AM
"30 15 * * *" // 3:30 PM
"0 18 * * *"  // 6:00 PM
```

### Change Attendance Threshold
**File:** `functions/index.js`

```javascript
// Line 282
const threshold = 75; // Change: 75% → 80% or 70%
```

### Change Time Zone
**File:** `functions/index.js`

```javascript
// Line 14
.timeZone("Asia/Kolkata")

// Other options:
// "Asia/Dubai"
// "America/New_York"
// "Europe/London"
```

---

## 📱 Flutter Integration

### Add Cloud Functions Package
**File:** `pubspec.yaml`

```yaml
dependencies:
  cloud_functions: ^4.7.0
```

### Create Unlock Service
**File:** `lib/services/attendance_unlock_service.dart`

```dart
import 'package:cloud_functions/cloud_functions.dart';

class AttendanceUnlockService {
  final _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');

  Future<void> unlockAttendance({
    required String schoolId,
    required String classSectionId,
    required String date,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('unlockAttendance')
          .call({
            'schoolId': schoolId,
            'classSectionId': classSectionId,
            'date': date,
          });

      if (result.data['success'] == true) {
        print('Attendance unlocked successfully');
      }
    } on FirebaseFunctionsException catch (e) {
      print('Error: ${e.code} - ${e.message}');
      rethrow;
    }
  }
}
```

### Admin UI - Unlock Button
**Add to your attendance screen:**

```dart
import 'package:flutter/material.dart';

ElevatedButton.icon(
  onPressed: () async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlock Attendance?'),
        content: const Text('This will allow editing of locked attendance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = AttendanceUnlockService();
      await service.unlockAttendance(
        schoolId: 'school_001',
        classSectionId: '5_A',
        date: '2026-02-21',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance unlocked!')),
      );
    }
  },
  icon: const Icon(Icons.lock_open),
  label: const Text('Unlock for Editing'),
  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
)
```

---

## 🧪 Testing

### Test Auto-Lock Locally
```bash
# Run emulator
cd functions
npm run serve

# In another terminal, trigger function manually
firebase functions:shell

> autoLockAttendance()
```

### Test Unlock Function
```bash
# Call from command line
firebase functions:call unlockAttendance --data '{
  "schoolId": "school_001",
  "classSectionId": "5_A",
  "date": "2026-02-21"
}'
```

### View Logs
```bash
# Real-time logs
firebase functions:log --follow

# Specific function
firebase functions:log --only autoLockAttendance

# Last 50 lines
firebase functions:log --limit 50
```

---

## 🔒 Security Rules

**Required Firestore Rule for Unlock:**
```javascript
match /schools/{schoolId}/users/{userId} {
  allow read: if request.auth != null && request.auth.uid == userId;
}
```

---

## 💰 Cost Estimation

| Function | Frequency | Invocations/Month | Cost (Approx) |
|----------|-----------|-------------------|---------------|
| Auto-Lock | Daily | 30 | $0.01 |
| Monthly Summary | Monthly | 1 | $0.001 |
| Low Attendance Alerts | Daily | 30 | $0.02 |
| Manual Unlock | On-demand | ~5 | $0.001 |

**Total: ~$0.03/month** (within Firebase free tier)

---

## 📊 Monitoring

### Check Function Status
```bash
firebase functions:list
```

### View Execution Logs
```bash
# Success logs
firebase functions:log | grep "success"

# Error logs
firebase functions:log | grep "Error"

# Specific date
firebase functions:log --since 2026-02-21
```

---

## 🐛 Troubleshooting

### Issue: Function not deploying
**Solution:**
```bash
cd functions
rm -rf node_modules
npm install
firebase deploy --only functions
```

### Issue: "Permission denied" on unlock
**Check:**
1. User is authenticated
2. User has `role: 'admin'` in Firestore
3. Security rules allow reading users collection

### Issue: Auto-lock not triggering
**Check:**
1. Functions are deployed: `firebase functions:list`
2. Schedule is correct (Cloud Scheduler enabled)
3. View logs: `firebase functions:log`

### Issue: Notifications not sending
**Check:**
1. Parent has valid `fcmToken` in Firestore
2. Student has `parentId` field
3. FCM is configured in Firebase Console

---

## 📦 Deployment Commands

```bash
# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:autoLockAttendance

# Deploy with specific project
firebase deploy --only functions --project school-app-prod

# Delete unused function
firebase functions:delete oldFunctionName
```

---

## 🔄 Update Existing Functions

After modifying `index.js`:
```bash
firebase deploy --only functions
```

Firebase will automatically update changed functions.

---

## 📝 Environment Variables (Optional)

If you need to store sensitive data:

```bash
# Set config
firebase functions:config:set attendance.lock_time="16" attendance.threshold="75"

# Get config
firebase functions:config:get

# Use in code
const lockTime = functions.config().attendance.lock_time;
```

---

## ✅ Post-Deployment Checklist

- [ ] Functions deployed successfully
- [ ] Auto-lock runs at 4:00 PM (check logs next day)
- [ ] Unlock function accessible from admin UI
- [ ] Monthly summary generates on 1st of month
- [ ] Low attendance alerts send notifications
- [ ] Logs are clean (no errors)
- [ ] Firebase billing set up (for production)

---

## 🎯 Summary

### What You Have Now:
✅ **4 Cloud Functions** - Auto-lock, unlock, summaries, alerts  
✅ **Scheduled Tasks** - Daily and monthly automation  
✅ **Admin Controls** - Manual unlock capability  
✅ **Parent Notifications** - Low attendance alerts  
✅ **Production Ready** - Error handling, logging, security

### To Activate:
1. `cd functions && npm install`
2. `firebase deploy --only functions`
3. Add unlock button to admin UI (Flutter code above)
4. Done! ✅

---

**Cost:** ~$0.03/month (within free tier)  
**Region:** asia-south1 (Mumbai)  
**Status:** Production-Ready 🚀

---

**Need Help?** Check logs with `firebase functions:log`
