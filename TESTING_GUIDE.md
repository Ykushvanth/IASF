# Testing Guide: New Onboarding & Level Assessment Flow

## Prerequisites

1. **Dependencies Installed** ✅
   ```bash
   flutter pub get
   ```
   (Already done - lottie package installed)

2. **Firebase Setup** ✅
   - Existing Firebase project connected
   - Authentication enabled
   - Firestore database ready

3. **API Keys** ✅
   - Groq API key configured in `level_assessment_backend.dart`
   - YouTube API key configured (for roadmap videos)

---

## Quick Start Testing

### Step 1: Run the App

```powershell
cd d:\dev\IASF
flutter run
```

Or press **F5** in VS Code to start debugging.

### Step 2: Create Test Account

1. Launch app
2. Sign up with a test email
3. Verify email if required

### Step 3: Complete Mindset Analysis (26 Questions)

**New Categories to Test:**
- Study Reality & Time Investment
- Clarity & Direction (includes multi-select question)
- Retention & Forgetting
- Practice & Application
- Exam Emotions & Anxiety (includes multi-select question)
- Confidence & Recovery
- Focus, Fatigue & Mental State
- Learning Behaviour & Habits (includes multi-select question)
- Motivation & Obstacles
- Reflection (includes text input question)

**Expected**: Progress bar shows 1/26, 2/26, ... 26/26

### Step 4: Select Exam

**Best exams for testing** (have topic lists):
- ✅ JEE (Joint Entrance Examination) - 10 topics
- ✅ NEET (National Eligibility cum Entrance Test) - 8 topics
- ✅ UPSC (Union Public Service Commission) - 8 topics

**Other exams** (limited topic lists):
- CAT, GATE, SSC, Banking, CLAT

### Step 5: Answer Course Questionnaire (5 Questions)

Standard questions about:
- Why pursuing exam
- Knowledge level
- Opportunities
- Study time available
- Exam timeline

**Expected**: Dialog shows "Course selection saved successfully" with AI insights

### Step 6: Level Assessment (NEW!)

#### A. Exam Knowledge Question
**Shows**: "How familiar are you with [Exam]?"
- Click **"Yes, I know the exam well"** to test full flow
- OR click **"Not really"** to skip to study plan

#### B. Topic Selection (if you clicked Yes)
**Shows**: List of exam-specific topics
- Check multiple topics you "know"
- Click **"Continue to Assessment"**

**Expected**: Loading spinner with "Generating personalized questions..."

#### C. Assessment Questions (10 MCQs)
**Shows**: 
- Progress bar (Question 1 of 10, etc.)
- Question text
- Four options (A, B, C, D)

**When you answer**:
- ✅ **Correct**: Green success animation + "Correct!" text
- ❌ **Wrong**: Red error animation + "Incorrect" text
- Automatically moves to next question after 2 seconds

**Expected**: Complete all 10 questions, see real-time feedback

#### D. Level Results
**Shows**:
- Your calculated level (Advanced/Intermediate/Beginner/Foundation)
- Performance summary (Correct vs Wrong count)
- Improvement areas (topics you got wrong)

**Click**: "Create My Study Plan"

#### E. Study Plan Details
**Shows**: Two questions
1. Study hours per day (chips: 1, 2, 3, 4, 5, 6, 8 hrs)
2. Days until exam (chips: 30, 60, 90, 180, 365 days)

**Click**: "Generate My Personalized Roadmap"

### Step 7: View Personalized Roadmap

**Expected**:
- Loading dialog: "Generating your personalized roadmap..."
- Roadmap screen appears with daily/weekly topics
- Each topic has video recommendations
- Roadmap considers your level, improvement areas, study time

---

## What to Test

### 1. Mindset Analysis Screen
- [ ] All 26 questions appear in order
- [ ] Progress bar updates correctly (1/26 → 26/26)
- [ ] Single-choice questions allow only one selection
- [ ] Multi-select questions (Q4, Q12, Q18) allow multiple selections
- [ ] Text input question (Q23) accepts typed input
- [ ] Previous button works correctly
- [ ] Next button is disabled until question is answered
- [ ] Finish button appears on question 26
- [ ] AI summary dialog appears after completion
- [ ] Data saves to Firebase

### 2. Course Selection Screen
- [ ] All 8 exams are displayed
- [ ] Cards are clickable
- [ ] Navigation to course questionnaire works

### 3. Course Questionnaire Screen
- [ ] All 5 questions appear
- [ ] Progress tracking works (Question 1 of 5, etc.)
- [ ] Submit button is enabled after all answers
- [ ] Success dialog appears
- [ ] Button says "Continue to Assessment" (not "View My Roadmap")
- [ ] Navigation to level assessment works

### 4. Level Assessment Screen

#### Step 0: Exam Knowledge
- [ ] Two cards display correctly
- [ ] "Yes" card navigates to topic selection
- [ ] "Not really" card skips to study plan

#### Step 1: Topic Selection (if Yes)
- [ ] Topics for selected exam appear
- [ ] Multiple topics can be selected
- [ ] Selected topics show checkmark and highlight
- [ ] Continue button is disabled if no topics selected
- [ ] Loading appears when generating questions

#### Step 2: Assessment Questions
- [ ] 10 questions are generated (check console for AI logs)
- [ ] Progress bar updates (1/10 → 10/10)
- [ ] Options are clickable
- [ ] Correct answer shows green animation
- [ ] Wrong answer shows red animation
- [ ] Animation appears for 2 seconds
- [ ] Auto-advances to next question
- [ ] All 10 questions complete

#### Step 3: Level Results
- [ ] Level is calculated correctly:
  - 8-10 correct = Advanced
  - 6-7 correct = Intermediate
  - 4-5 correct = Beginner
  - 0-3 correct = Foundation
- [ ] Correct/Wrong counts match
- [ ] Improvement areas list wrong topics
- [ ] Button navigates to study plan

#### Step 4: Study Plan
- [ ] Study hours chips are selectable
- [ ] Days until exam chips are selectable
- [ ] Generate button is disabled until both selected
- [ ] Loading appears when generating roadmap

### 5. Roadmap Screen
- [ ] Roadmap generates successfully
- [ ] Topics are specific and relevant
- [ ] Videos are included for topics
- [ ] Progress can be tracked
- [ ] Firebase saves roadmap data

### 6. Firebase Data Check

Check Firestore `users/{userId}` document contains:

```javascript
{
  // Updated mindset answers (26 keys: q1-q26)
  "mindsetAnswers": {
    "q1": "2–4 hours",
    "q2": "Mostly consistent",
    // ... through q26
  },
  
  // NEW: Level assessment results
  "levelAssessment": {
    "courseName": "JEE (Joint Entrance Examination)",
    "knowsExam": true,
    "selectedTopics": ["Physics - Mechanics", ...],
    "userLevel": "Intermediate",
    "correctAnswers": 7,
    "totalQuestions": 10,
    "score": 70,
    "improvementAreas": ["Chemistry - Organic"],
    "studyHoursPerDay": 4,
    "daysUntilExam": 180,
    "timestamp": (Firestore Timestamp)
  },
  
  // Course answers
  "courseAnswers": { ... },
  
  // Generated roadmap
  "roadmap": [ ... ]
}
```

---

## Common Issues & Solutions

### Issue 1: Animation Not Showing
**Symptom**: No animation when answering questions  
**Solution**: 
1. Check `assets/animations/correct.json` and `wrong.json` exist
2. Run `flutter clean` then `flutter pub get`
3. Replace with better animations from LottieFiles

### Issue 2: AI Questions Not Generating
**Symptom**: Loading spinner stays forever or shows error  
**Solution**:
1. Check Groq API key in `level_assessment_backend.dart`
2. Check internet connection
3. Fallback questions should appear if AI fails
4. Check console for error logs

### Issue 3: Topics Not Showing
**Symptom**: Empty topic list in level assessment  
**Solution**:
1. Ensure you selected JEE, NEET, or UPSC (others have minimal topics)
2. Check `_examTopics` map in `exam_level_assessment.dart`
3. Add topics for other exams if needed

### Issue 4: Roadmap Fails to Generate
**Symptom**: Error after study plan submission  
**Solution**:
1. Check Firebase Firestore rules allow writes
2. Check Groq API key in `roadmap_backend.dart`
3. Check console for detailed error logs
4. Verify mindsetAnswers exist in Firebase

### Issue 5: Multi-select Questions Not Working
**Symptom**: Can't select multiple options  
**Solution**:
1. Check questions Q4, Q12, Q18 use `_buildMultipleChoiceQuestion`
2. Verify answers are stored as `List<String>`
3. Check console logs for answer structure

---

## Console Logs to Watch

### Mindset Analysis
```
🚀 _submitAnalysis CALLED!
✅ Loading state set to true
📝 Submitting answers: [q1, q2, ..., q26]
📝 Total answers: 26
🔥 Calling Firebase save...
✅ Firebase save result: true
✅✅✅ FIREBASE SAVE SUCCESSFUL!
🤖 Starting Groq API call...
✅ Groq result: true
```

### Level Assessment - Question Generation
```
🎯 Generating assessment questions...
📚 Course: JEE (Joint Entrance Examination)
📝 Selected topics: [Physics - Mechanics, Chemistry - Organic]
📡 Groq API Response Status: 200
🤖 Raw AI Response: [JSON array]
✅ Generated 10 questions
```

### Level Assessment - Saving Results
```
💾 Saving assessment results...
✅ Assessment results saved successfully
```

### Roadmap Generation
```
═══════════════════════════════════════════════════════
🗺️ Starting PERSONALIZED roadmap generation
📚 Course: JEE (Joint Entrance Examination)
🧠 Mindset profile keys: q1, q2, ..., q26
📊 User Level: Intermediate
📈 Improvement Areas: Chemistry - Organic
⏰ Study Hours/Day: 4
📅 Days Until Exam: 180
═══════════════════════════════════════════════════════
```

---

## Expected Test Duration

- **Mindset Analysis**: 5-8 minutes (26 questions)
- **Course Selection**: 10 seconds
- **Course Questionnaire**: 1-2 minutes (5 questions)
- **Level Assessment**: 
  - Exam knowledge: 5 seconds
  - Topic selection: 30 seconds
  - Assessment questions: 3-5 minutes (10 questions)
  - Results: 30 seconds
  - Study plan: 30 seconds
- **Roadmap Generation**: 30-60 seconds

**Total Complete Flow**: ~15-20 minutes

---

## Success Criteria

✅ **All 26 mindset questions answered and saved**  
✅ **Course selected and preferences saved**  
✅ **Level assessment completed (if user knows exam)**  
✅ **User level determined accurately**  
✅ **Animations show for correct/wrong answers**  
✅ **Study plan details collected**  
✅ **Personalized roadmap generated**  
✅ **All data saved to Firebase**  
✅ **No crashes or errors**  

---

## Need Help?

Check these files for debugging:
- `lib/screens/mindset_analysis.dart` - Mindset questions
- `lib/screens/exam_level_assessment.dart` - Level assessment flow
- `lib/models/level_assessment_backend.dart` - AI question generation
- `lib/models/roadmap_backend.dart` - Roadmap generation

Look for print statements with emojis (🚀, ✅, ❌, 🎯, etc.) in the console.

---

## Next Steps After Testing

1. **Improve Animations**
   - Download better Lottie files from LottieFiles.com
   - Replace `assets/animations/correct.json` and `wrong.json`

2. **Add More Topics**
   - Expand `_examTopics` for CAT, GATE, SSC, Banking, CLAT
   - Add at least 8-10 topics per exam

3. **Enhance AI Questions**
   - Improve Groq prompts for better quality questions
   - Add difficulty balancing logic
   - Include explanations for answers

4. **Polish UI**
   - Add more visual feedback
   - Improve loading states
   - Add skip/back options where needed

5. **Analytics**
   - Track completion rates
   - Monitor where users drop off
   - Collect feedback on question quality

---

## Happy Testing! 🎉

If everything works as expected, you now have a comprehensive, AI-powered onboarding system that creates highly personalized learning experiences!
