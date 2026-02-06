# Backend Connection Fix Guide

## ✅ Changes Made

1. **Removed mock mode code** from `AuthenticationService.swift`
2. **Created `BackendConnectionTestView.swift`** - A debugging tool to test your backend connection
3. **Enhanced error logging** - You'll see detailed error messages in the console

## 🔧 How to Fix Your Connection

### Step 1: Start Your Backend Server Correctly

**The most important thing:** Your backend must listen on `0.0.0.0:8000`, NOT just `localhost:8000`.

**Django:**
```bash
python manage.py runserver 0.0.0.0:8000
```

**Flask:**
```bash
flask run --host=0.0.0.0 --port=8000
```

**FastAPI:**
```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```

**Node.js/Express:**
```javascript
app.listen(8000, '0.0.0.0', () => {
  console.log('Server listening on all interfaces');
});
```

### Step 2: Verify Your Mac's IP Address

Check if your IP is still `192.168.1.52`:

```bash
# Get your current IP:
ipconfig getifaddr en0

# Or see all IPs:
ifconfig | grep "inet " | grep -v 127.0.0.1
```

If your IP has changed, update line 39 in `APIClient.swift`:
```swift
return "http://YOUR_NEW_IP:8000/v1"
```

### Step 3: Test Backend Accessibility

From your Mac's Terminal:

```bash
# Test if server is running:
lsof -i :8000

# Test the endpoint:
curl http://localhost:8000/v1/auth/apple

# Test with your IP (this is what your iPhone will try):
curl http://192.168.1.52:8000/v1/auth/apple
```

### Step 4: Configure App Transport Security

Since you're using HTTP (not HTTPS), you need to allow it:

1. In Xcode, select your **Pulse** project
2. Select the **Pulse** target
3. Go to **Info** tab
4. Right-click → **Add Row**
5. Add:
   - **Key:** `App Transport Security Settings` (NSAppTransportSecurity)
   - **Type:** Dictionary
6. Expand it and add:
   - **Key:** `Allow Local Networking` (NSAllowsLocalNetworking)
   - **Type:** Boolean
   - **Value:** YES

### Step 5: Check Firewall Settings

1. Open **System Settings** → **Network** → **Firewall**
2. If enabled, make sure your backend app is allowed
3. Or temporarily disable firewall for testing

### Step 6: Verify Same Network

Your iPhone/iPad and Mac must be on the **same Wi-Fi network**.

## 🧪 Use the Connection Test Tool

I created `BackendConnectionTestView` for you. To use it, add this button somewhere in your app (like in WelcomeView or a settings screen):

```swift
#if DEBUG
NavigationLink {
    BackendConnectionTestView()
} label: {
    Label("Test Backend Connection", systemImage: "network")
}
#endif
```

This tool will:
- Test the connection to your backend
- Show exactly what's wrong
- Provide specific error messages
- Give you troubleshooting steps

## 🐛 Debugging with Console Logs

When you try to sign in, watch the Xcode console for these logs:

```
🔐 ========== STARTING APPLE SIGN IN ==========
🔐 Step 1: Creating ASAuthorizationAppleIDProvider
...
🔐 Step 10: Sending request to backend at /auth/apple...
```

If you see a network error, it will show:
```
🔐 ❌ Backend exchange failed!
🔐 Error type: APIError
🔐 URL Error code: -1004
```

Common error codes:
- `-1004` = Cannot connect to host (server not running)
- `-1003` = Cannot find host (wrong IP address)
- `-1001` = Timeout (network issues)

## 📱 Common Issues & Solutions

### Issue: "Cannot connect to host"
**Solution:** Backend server isn't running or isn't listening on `0.0.0.0`

### Issue: "Cannot find host"
**Solution:** Your Mac's IP address changed. Run `ipconfig getifaddr en0` and update `APIClient.swift`

### Issue: "Connection works from Mac but not from iPhone"
**Solution:** 
- Make sure server listens on `0.0.0.0`, not `localhost`
- Check you're on the same Wi-Fi
- Check firewall settings

### Issue: "App Transport Security" error
**Solution:** Add `NSAllowsLocalNetworking` to Info.plist (see Step 4 above)

## ✅ Checklist Before Testing

- [ ] Backend server is running
- [ ] Server listens on `0.0.0.0:8000` (not just `localhost`)
- [ ] Mac IP address is still `192.168.1.52` (or updated in code)
- [ ] iPhone/iPad and Mac are on same Wi-Fi
- [ ] Firewall allows connections
- [ ] `NSAllowsLocalNetworking` is in Info.plist
- [ ] Tested with `curl http://192.168.1.52:8000/v1/auth/apple` from Mac

## 🎯 Quick Test

Run this from your Mac's Terminal:

```bash
# This command tests what your iPhone will try to connect to:
curl -v http://192.168.1.52:8000/v1/auth/apple
```

If this doesn't work, your iPhone won't be able to connect either.

Expected responses:
- **Good:** Any HTTP response (even 404 or 405)
- **Bad:** "Connection refused" or "Could not connect"

## 📞 Need Help?

Use the `BackendConnectionTestView` - it will tell you exactly what's wrong!
