# 🚀 Quick Deploy - Cloud Functions

## ⚡ Option 1: Double-Click Method (Easiest)

1. **Double-click:** `deploy_functions.bat`
2. **Choose:** Option 1 (Deploy all functions)
3. **Wait:** 2-3 minutes for deployment
4. **Done!** ✅

---

## ⚡ Option 2: Command Line

### If you get "scripts disabled" error:

Run this **once** in PowerShell (as Administrator):
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Then run:
```bash
# 1. Install dependencies
cd functions
npm install

# 2. Deploy functions
cd ..
firebase deploy --only functions

# 3. View logs
firebase functions:log
```

---

## ⚡ Option 3: Deploy from pull.text commands

Add these to your `pull.text` file:

```bash
# Deploy Functions
cd functions
npm install
cd ..
firebase deploy --only functions
firebase functions:log
```

---

## ✅ Verify Deployment

After deployment, you should see:
```
✔  functions[autoLockAttendance(asia-south1)] Successful update
✔  functions[unlockAttendance(asia-south1)] Successful update
✔  functions[generateMonthlySummaries(asia-south1)] Successful update
✔  functions[sendLowAttendanceAlerts(asia-south1)] Successful update

✔  Deploy complete!
```

---

## 📊 Check Status

```bash
# List all functions
firebase functions:list

# View recent logs
firebase functions:log --limit 20

# Follow logs in real-time
firebase functions:log --follow
```

---

## 🔧 Troubleshooting

### Error: "npm command not found"
**Install Node.js:** https://nodejs.org/

### Error: "firebase command not found"
```bash
npm install -g firebase-tools
firebase login
```

### Error: "Permission denied"
Run PowerShell as Administrator, then:
```powershell
Set-ExecutionPolicy RemoteSigned
```

---

## 📅 Schedule Summary

| Function | When | Time |
|----------|------|------|
| **Auto-Lock** | Daily | 4:00 PM |
| **Monthly Summary** | 1st of month | 1:00 AM |
| **Low Attendance Alert** | Daily | 8:00 PM |
| **Manual Unlock** | On-demand | Anytime |

---

## 🎯 Next Steps

1. ✅ Deploy functions (using method above)
2. ✅ Wait until tomorrow 4:00 PM to see auto-lock in action
3. ✅ Add unlock button to admin UI (see CLOUD_FUNCTIONS_SETUP_GUIDE.md)
4. ✅ Test unlock functionality

---

**Deploy Status:** Ready to deploy! Run `deploy_functions.bat` now. 🚀
