# Sign In Connection Issues - Fixed! 🎉

## The Problem
When signing in with Apple, you're seeing this error:
```
Could not connect to server. Please check your network connection and ensure the server is running.
```

**What's happening:**
1. ✅ Sign in with Apple works (Apple authentication succeeds)
2. ❌ Backend exchange fails (can't reach http://192.168.1.52:8000/v1/auth/apple)

## Solution Options

### Option 1: Use Mock Mode (Quickest Fix) 🎭

**This lets you test your app WITHOUT needing the backend server!**

1. Add `DeveloperSettingsView` to your app (already created for you)
2. Navigate to it and toggle "Use Mock API" to ON
3. Try signing in again - it will work with fake data!

To add it to your app, somewhere in your UI add:
```swift
NavigationLink {
    DeveloperSettingsView()
} label: {
    Label("Developer Settings", systemImage: "hammer.fill")
}
```

Or for quick testing, just run this in your code:
```swift
UserDefaults.standard.set(true, forKey: "UseMockAPI")
```

### Option 2: Fix the Backend Connection 🔧

If you want to connect to your real backend:

#### Step 1: Start Your Backend Server
```bash
# Make sure your backend is running on port 8000
# Check if anything is listening:
lsof -i :8000

# Test the endpoint:
curl http://localhost:8000/v1/auth/apple
```

#### Step 2: Update IP Address (If Changed)
Your Mac's IP is currently set to: **192.168.1.52**

To check if it changed:
1. Open **System Settings** → **Network**
2. Look for your Wi-Fi connection and find your IP address
3. If different, update `APIClient.swift` line 36

#### Step 3: Verify Network Settings
- Device and Mac must be on the **same Wi-Fi network**
- Mac's firewall should allow connections on port 8000

#### Step 4: Test Connection
Use the included `ServerConnectionDebugView` to test:
```swift
// In your app, navigate to:
ServerConnectionDebugView()
```

This will tell you exactly what's wrong with the connection.

### Option 3: Add App Transport Security Configuration 🔒

If you haven't already, you may need to allow HTTP connections:

1. In Xcode, select your **Pulse** target
2. Go to **Info** tab
3. Add this entry:
   - Key: `NSAppTransportSecurity` (Dictionary)
   - Add child: `NSAllowsLocalNetworking` (Boolean) = `YES`

## What I Fixed for You

### 1. Enhanced Error Messages
- `APIClient.swift` now shows clear, specific error messages
- You'll see exactly why the connection failed

### 2. Added Mock Mode
- `MockAPIClient.swift` - Returns fake data so you can develop without backend
- `AuthenticationService.swift` - Checks for mock mode and uses it when enabled

### 3. Developer Tools
- `DeveloperSettingsView.swift` - Easy toggle for mock mode + troubleshooting tips
- `ServerConnectionDebugView.swift` - Test your server connection with one tap

### 4. Better Logging
- Step-by-step console output during sign in
- Shows exactly where the process fails

## Quick Start Guide

### For Development (No Backend):
```swift
// Enable mock mode
UserDefaults.standard.set(true, forKey: "UseMockAPI")
// Now sign in will work!
```

### For Real Backend:
1. Start your backend: `python manage.py runserver 8000` (or similar)
2. Verify it's accessible: `curl http://localhost:8000`
3. Make sure mock mode is OFF
4. Try signing in

## Debugging Tips

### Check Console Output
When you sign in, look for these logs:
```
🔐 ========== STARTING APPLE SIGN IN ==========
🔐 Step 1: Creating ASAuthorizationAppleIDProvider
...
🔐 Step 10: Sending request to backend at /auth/apple...
```

If you see `🎭 MOCK MODE ENABLED` - you're using fake data (no backend needed)

If you see the network error - backend connection is the problem

### Common Errors

**"Cannot connect to host"**
→ Backend server isn't running

**"Connection timed out"**
→ Backend is running but not responding (check port, firewall)

**"App Transport Security blocking"**
→ Need to add `NSAllowsLocalNetworking` to Info.plist

## Need More Help?

Run the `ServerConnectionDebugView` - it will tell you exactly what's wrong!

```swift
// Add this somewhere in your app:
Button("Test Server Connection") {
    showServerDebug = true
}
.sheet(isPresented: $showServerDebug) {
    NavigationStack {
        ServerConnectionDebugView()
    }
}
```
