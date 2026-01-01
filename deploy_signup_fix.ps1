#!/usr/bin/env pwsh

Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         EduAi Signup Fix - Deployment Checklist         ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Check 1: Firebase CLI installed
Write-Host "🔍 Checking Firebase CLI..." -ForegroundColor Yellow
$firebaseVersion = firebase --version 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Firebase CLI installed: $firebaseVersion`n" -ForegroundColor Green
} else {
    Write-Host "⚠️  Firebase CLI not found. Install with: npm install -g firebase-tools`n" -ForegroundColor Yellow
}

# Check 2: Flutter environment
Write-Host "🔍 Checking Flutter..." -ForegroundColor Yellow
$flutterVersion = flutter --version 2>&1 | Select-String "Flutter" | Select-Object -First 1
if ($flutterVersion) {
    Write-Host "✅ Flutter installed: $flutterVersion`n" -ForegroundColor Green
} else {
    Write-Host "❌ Flutter not found`n" -ForegroundColor Red
    exit 1
}

# Check 3: Firestore rules file
Write-Host "🔍 Checking Firestore rules..." -ForegroundColor Yellow
if (Test-Path "firestore.rules") {
    Write-Host "✅ firestore.rules found`n" -ForegroundColor Green
} else {
    Write-Host "❌ firestore.rules not found`n" -ForegroundColor Red
    exit 1
}

Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    Deployment Steps                      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "Step 1: Deploy Firestore Rules" -ForegroundColor Cyan
Write-Host "-------------------------------" -ForegroundColor Gray
$deployRules = Read-Host "Deploy Firestore rules now? (y/n)"
if ($deployRules -eq 'y') {
    Write-Host "`nDeploying Firestore rules..." -ForegroundColor Yellow
    firebase deploy --only firestore:rules
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Firestore rules deployed successfully!" -ForegroundColor Green
        Write-Host "⏳ Waiting 10 seconds for rules to propagate..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
    } else {
        Write-Host "❌ Failed to deploy Firestore rules" -ForegroundColor Red
        Write-Host "   Manual deployment:" -ForegroundColor Yellow
        Write-Host "   1. Go to Firebase Console" -ForegroundColor Gray
        Write-Host "   2. Firestore Database → Rules" -ForegroundColor Gray
        Write-Host "   3. Copy content from firestore.rules" -ForegroundColor Gray
        Write-Host "   4. Publish and wait 30-60 seconds`n" -ForegroundColor Gray
    }
}

Write-Host "`nStep 2: Clean and Build" -ForegroundColor Cyan
Write-Host "------------------------" -ForegroundColor Gray
$cleanBuild = Read-Host "Run flutter clean and rebuild? (y/n)"
if ($cleanBuild -eq 'y') {
    Write-Host "`nCleaning Flutter project..." -ForegroundColor Yellow
    flutter clean
    
    Write-Host "Getting dependencies..." -ForegroundColor Yellow
    flutter pub get
    
    Write-Host "✅ Project cleaned and dependencies updated`n" -ForegroundColor Green
}

Write-Host "`nStep 3: Run the App" -ForegroundColor Cyan
Write-Host "-------------------" -ForegroundColor Gray
$runApp = Read-Host "Run the app now? (y/n)"
if ($runApp -eq 'y') {
    Write-Host "`nStarting Flutter app..." -ForegroundColor Yellow
    Write-Host "Watch console for signup logs (✅/❌ indicators)`n" -ForegroundColor Gray
    flutter run
}

Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    Testing Checklist                     ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "📋 Test Signup with:" -ForegroundColor Yellow
Write-Host "   • Email: testuser@example.com" -ForegroundColor Gray
Write-Host "   • Phone: 9876543210 (10 digits)" -ForegroundColor Gray
Write-Host "   • Password: password123 (min 6 chars)" -ForegroundColor Gray
Write-Host "   • Name: Test User" -ForegroundColor Gray
Write-Host ""

Write-Host "👀 Watch for these logs:" -ForegroundColor Yellow
Write-Host "   ✅ Firebase Auth user created" -ForegroundColor Green
Write-Host "   📝 Creating Firestore user document" -ForegroundColor Blue
Write-Host "   ✅ Firestore document created successfully" -ForegroundColor Green
Write-Host "   ✅ Firestore document verified" -ForegroundColor Green
Write-Host ""

Write-Host "🚨 If signup fails, check:" -ForegroundColor Yellow
Write-Host "   1. Error message in the app" -ForegroundColor Gray
Write-Host "   2. Console logs with ❌ indicator" -ForegroundColor Gray
Write-Host "   3. Firebase Console → Authentication" -ForegroundColor Gray
Write-Host "   4. Firebase Console → Firestore" -ForegroundColor Gray
Write-Host "   5. See SIGNUP_FIX_GUIDE.md for solutions`n" -ForegroundColor Gray

Write-Host "📖 For detailed troubleshooting, see: " -ForegroundColor Cyan -NoNewline
Write-Host "SIGNUP_FIX_GUIDE.md`n" -ForegroundColor White
