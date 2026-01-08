# Animation Assets

This directory contains Lottie JSON animation files used in the app.

## Required Files

1. **correct.json** - Animation shown when user answers correctly
   - Download from: https://lottiefiles.com/animations/success-checkmark
   - Recommended: Green checkmark or success animation

2. **wrong.json** - Animation shown when user answers incorrectly  
   - Download from: https://lottiefiles.com/animations/error-cross
   - Recommended: Red X or error animation

## How to Add Animations

1. Visit [LottieFiles.com](https://lottiefiles.com/)
2. Search for "success" and "error" animations
3. Download as JSON (Lottie JSON format)
4. Rename files to `correct.json` and `wrong.json`
5. Place them in this directory

## Alternative: Create Placeholder Files

If you want to test without animations, you can create simple placeholder JSON files:

```json
{
  "v": "5.5.7",
  "meta": { "g": "LottieFiles AE ", "a": "", "k": "", "d": "", "tc": "" },
  "fr": 60,
  "ip": 0,
  "op": 60,
  "w": 400,
  "h": 400,
  "nm": "Animation",
  "ddd": 0,
  "assets": [],
  "layers": []
}
```

This will prevent errors but won't show an actual animation.
