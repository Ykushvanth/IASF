# Roadmap Generation Improvements - December 29, 2024 (Updated)

## Problems Fixed
1. **Issue 1**: Roadmap showing same videos throughout the week with same generic heading
2. **Issue 2**: Card names not representing the specific topic being covered
3. **Issue 3**: Videos not properly filtered by user's preferred language
4. **Issue 4**: Videos not aligned with user's mindset and learning style
5. **Issue 5**: Video descriptions not checked for relevance to the topic

## Comprehensive Solutions Implemented

### 1. **Enhanced Topic Extraction & Specificity**
   - **Multiple Pattern Matching**: Uses 3 different regex patterns to extract daily topics from AI response
   - **Robust Parsing**: Handles bullet points (•), newlines, commas, and semicolons
   - **Fallback Logic**: If parsing fails, creates unique topics by appending day numbers
   - **Topic Validation**: Ensures topics are at least 5 characters and meaningful
   
   #### Example Parsing:
   ```
   Input: "Day 1: Linear Algebra - Matrices • Day 2: Calculus - Derivatives"
   Output: ["Linear Algebra - Matrices", "Calculus - Derivatives"]
   ```

### 2. **Video Relevance Scoring System** 🎯
   - **New Algorithm**: Calculates 0-100 relevance score for each video
   - **Scoring Components**:
     - Exact phrase match in title: +40 points
     - Exact phrase match in description: +25 points
     - Individual keyword matches: +5 points (title), +2 points (description)
     - Video style keyword matches: +3 points (title), +1 point (description)
     - Educational indicators (tutorial, explained, guide): +2 points
     - High keyword coverage bonus: +10-15 points
   
   - **Filtering**: Only videos with relevance score ≥30% are shown
   - **Ranking**: Sorts by combined score (60% relevance + 40% engagement)

### 3. **Mindset-Based Video Style Selection**
   - Analyzes user's mindset profile to determine optimal video style
   - **High Confusion/Fear** → "beginner friendly step by step"
   - **Frequent Forgetting** → "easy to remember concept explanation"
   - **Visual Learner** → "animated visual tutorial"
   - **Prefers Quick Content** → "quick concept overview"
   - **Default** → "clear tutorial explained simply"

### 4. **Improved Video Search Query**
   - **Course Context**: Includes course name in search
   - **Clean Topics**: Removes generic words (study, learn, understand)
   - **Channel Prioritization**: Adds recommended channels to query
   - **Language Integration**: Appends "in [Language]" for non-English
   
   #### Example Queries:
   ```
   Before: "study mathematics tutorial"
   After: "GATE Mathematics Linear Algebra - Matrices 3Blue1Brown tutorial explanation in Hindi"
   ```

### 5. **Video Description Analysis**
   - **Content Checking**: Analyzes both title and description for topic relevance
   - **Keyword Extraction**: Identifies key terms from topic name
   - **Stop Words**: Filters out common words (the, and, or, etc.)
   - **Educational Indicators**: Looks for tutorial-specific keywords
   - **Match Percentage**: Calculates how many topic keywords appear in video

### 6. **Language Preference Integration**
   - Videos searched specifically in user's preferred language
   - Language code passed to YouTube API (`relevanceLanguage` parameter)
   - Language appended to search query for better results
   - Supported languages: English, Hindi, Telugu, Tamil, Kannada, Malayalam, Bengali, Marathi, Gujarati, Punjabi, Spanish, French, German

### 7. **Enhanced Logging & Debugging**
   - Logs each day's topic as it's generated
   - Shows relevance scores for selected videos
   - Displays search queries being used
   - Tracks daily topic parsing success/failure
   - Reports video filtering statistics

## Technical Implementation

### File Modified: `lib/models/roadmap_backend.dart`

#### 1. **Daily Topic Extraction** (Lines ~468-520)
```dart
// Pattern 1: "Day 1: Topic • Day 2: Topic"
var dayPattern = RegExp(r'Day \d+:\s*([^•]+)', multiLine: true);

// Pattern 2: Newline separation
dayPattern = RegExp(r'Day \d+:\s*([^\n]+)', multiLine: true);

// Pattern 3: Comma/semicolon separation
final topics = dailyBreakdown.split(RegExp(r'[,;]'));

// Fallback: Unique topics with day numbers
dayTopic = '$weekTopic - Part $dayInWeek';
```

#### 2. **Video Relevance Calculation** (Lines ~963-1046)
```dart
double _calculateVideoRelevance(
  String topic,
  String videoTitle,
  String videoDescription,
  String videoStyle,
) {
  // Extract keywords from topic
  // Score based on exact matches, keyword matches, style alignment
  // Return 0-100 score
}
```

#### 3. **Combined Scoring & Filtering** (Lines ~920-945)
```dart
// Filter low relevance videos
videos = videos.where((v) => v['relevanceScore'] >= 30.0).toList();

// Sort by combined score: 60% relevance + 40% engagement
final combinedScore = (relevance * 0.6) + (engagement * 0.4);
```

## Example: GATE Computer Science Roadmap (90 Days)

### Before (Generic & Repetitive):
```json
{
  "week": 1,
  "weekTheme": "Mathematics Foundation",
  "days": [
    {"day": 1, "topic": "Study Mathematics", "videos": [/* generic math videos */]},
    {"day": 2, "topic": "Study Mathematics", "videos": [/* same videos */]},
    {"day": 3, "topic": "Study Mathematics", "videos": [/* same videos */]},
    // ... same for 7 days
  ]
}
```

### After (Specific & Unique):
```json
{
  "week": 1,
  "weekTheme": "Mathematics Foundation",
  "days": [
    {
      "day": 1,
      "topic": "Linear Algebra - Matrices and Determinants",
      "recommendedChannels": ["3Blue1Brown", "Khan Academy"],
      "videos": [
        {
          "title": "Matrices and Determinants - Complete Tutorial",
          "relevanceScore": 87.5,
          "language": "Hindi"
        }
      ]
    },
    {
      "day": 2,
      "topic": "Calculus - Limits and Continuity",
      "recommendedChannels": ["Khan Academy", "Organic Chemistry Tutor"],
      "videos": [
        {
          "title": "Limits and Continuity Explained in Hindi",
          "relevanceScore": 92.3,
          "language": "Hindi"
        }
      ]
    },
    {
      "day": 3,
      "topic": "Differential Equations - First Order",
      "recommendedChannels": ["MIT OpenCourseWare", "Khan Academy"],
      "videos": [
        {
          "title": "First Order Differential Equations - Step by Step",
          "relevanceScore": 89.1,
          "language": "Hindi"
        }
      ]
    }
    // ... unique topics for each day
  ]
}
```

### Week 2 Example (Continuing with Different Topics):
```json
{
  "week": 2,
  "weekTheme": "Data Structures Fundamentals",
  "days": [
    {"day": 8, "topic": "Arrays and Linked Lists - Implementation"},
    {"day": 9, "topic": "Stacks and Queues - Applications"},
    {"day": 10, "topic": "Trees - Binary Trees and BST"},
    {"day": 11, "topic": "Graph Theory - Representation"},
    {"day": 12, "topic": "Hashing - Hash Tables and Collision"},
    {"day": 13, "topic": "Practice - Data Structure Problems"},
    {"day": 14, "topic": "Revision - Data Structures Week"}
  ]
}
```

## Expected Results

### Card Display:
- ✅ **Day 1**: "Linear Algebra - Matrices and Determinants" (not "Study Mathematics")
- ✅ **Day 2**: "Calculus - Limits and Continuity" (different from Day 1)
- ✅ **Day 3**: "Differential Equations - First Order" (completely unique)

### Video Quality:
- ✅ **Relevant**: Videos match the exact topic (Matrices videos for Matrices topic)
- ✅ **Language**: All videos in user's preferred language (e.g., Hindi)
- ✅ **Duration**: 4-20 minutes (focused learning, not 2-hour lectures)
- ✅ **Mindset-Aligned**: Video style matches user's learning preference
- ✅ **High Quality**: Combines relevance (60%) and engagement (40%) scores

### Logging Output Example:
```
📖 Parsing daily breakdown: Day 1: Linear Algebra - Matrices • Day 2: Calculus...
✅ Extracted 7 daily topics from breakdown
   First topic: Linear Algebra - Matrices and Determinants
📝 Day 1: Linear Algebra - Matrices and Determinants
📝 Day 2: Calculus - Limits and Continuity
🔍 Final search query: GATE Mathematics Linear Algebra - Matrices 3Blue1Brown tutorial explanation in Hindi
✅ Selected 3 high-quality, relevant videos in Hindi for: Linear Algebra - Matrices
   Top video: "Matrices Complete Tutorial in Hindi" (Relevance: 92.3%)
```

## How to Test

1. **Clear old roadmap and generate new one**:
   ```dart
   await RoadmapBackend.clearRoadmap();
   // Then create new roadmap from app
   ```

2. **Check Console Logs**:
   - Look for "📝 Day X: [Topic Name]" - each should be different
   - Check relevance scores - should be >30%
   - Verify search queries include specific topics

3. **Verify in UI**:
   - Open roadmap screen
   - Each day card should show specific topic name
   - Tap on day to see videos
   - Videos should match the topic exactly
   - Videos should be in your preferred language

4. **Test Different Scenarios**:
   - GATE exam with 90 days (should get 13 weeks of unique topics)
   - JEE with 120 days (should get 17 weeks)
   - Python course with 30 days (day-by-day specific lessons)

## Benefits

### For Students:
- 📚 **Clear Daily Goals**: Know exactly what to study each day
- 🎯 **Focused Content**: Videos match the exact topic, no irrelevant content
- 🌍 **Native Language**: Learn in your comfortable language
- 🧠 **Personalized**: Content matches your learning style and mindset
- ⏱️ **Time Efficient**: Concise videos, no 2-hour lectures
- 📈 **Progressive**: Topics build on each other logically

### For GATE/JEE/NEET Preparation:
- Each subject broken into specific chapters/topics
- No repetition - every day covers new ground
- Syllabus-aligned topic progression
- Recommended channels for each subject area
- Language preference for regional students

### For Skill Learning (Python, Web Dev, etc.):
- Step-by-step progression from basics to advanced
- Each day = one concept/skill
- Practical, project-oriented approach
- Code-along friendly video lengths

## Future Enhancements (Possible)

- [ ] Allow users to manually edit/reorder topics
- [ ] Add quiz questions based on video content
- [ ] Track video watch progress
- [ ] Suggest alternate videos if first choice doesn't help
- [ ] Add practice problem links for each topic
- [ ] Enable topic-level completion tracking
- [ ] Add notes section for each topic
- [ ] Community ratings for videos

## Troubleshooting

**If topics still look generic:**
1. Check console logs for "📖 Parsing daily breakdown"
2. Verify AI is generating specific topics in the prompt response
3. Increase `max_tokens` in AI request if topics are truncated

**If videos don't match topic:**
1. Check relevance scores in logs (should be >30%)
2. Verify search query includes specific topic terms
3. Check if YouTube API quota is exhausted

**If videos not in preferred language:**
1. Verify user profile has correct language setting
2. Check search query includes "in [Language]"
3. Some technical topics may have limited non-English content
