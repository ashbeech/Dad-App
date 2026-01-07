# Dad App (Ambition MVP)

> **Note:** This codebase is transitioning from a baby tracking app ("Dad App") to an AI-powered goal achievement platform ("Ambition"). The core infrastructure for AI-driven task generation is now implemented.

## What This App Does

Users enter ambitious goals (e.g., "Launch a SaaS product") and the AI:

1. Breaks the goal into **milestones** (major checkpoints)
2. Generates **actionable tasks** scheduled across days/weeks
3. Learns from user behavior to **personalize future plans**

The app uses a time-based "arc" interface to visualize daily schedules.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         iOS App (SwiftUI)                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ AddGoalView │  │ DataStore   │  │ AIService               │  │
│  │ (UI)        │──│ (State)     │──│ (API Client)            │  │
│  └─────────────┘  └─────────────┘  └───────────┬─────────────┘  │
└────────────────────────────────────────────────┼────────────────┘
                                                 │ HTTP POST
                                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Node.js/Express Server                        │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ POST /api/breakdown                                      │    │
│  │ - Receives: goal, deadline, preferences, behavioralProfile│   │
│  │ - Calls: Groq LLM API                                    │    │
│  │ - Returns: milestones[], tasks[]                         │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                                                 │
                                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Groq LLM API                             │
│                    (llama-3.3-70b-versatile)                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
Dad App/
├── Dad App/                          # iOS App Source
│   ├── DadTrackApp.swift             # App entry point
│   ├── ContentView.swift             # Main view with arc interface
│   │
│   ├── # CORE DATA MODELS
│   ├── GoalEvent.swift               # Goal with milestones and tasks
│   ├── Milestone.swift               # Checkpoint within a goal
│   ├── TaskEvent.swift               # Individual actionable task
│   ├── TaskObservation.swift         # Behavioral tracking record
│   ├── UserExecutionProfile.swift    # Calculated behavioral metrics
│   ├── UserPreferences.swift         # User's scheduling preferences
│   │
│   ├── # STATE MANAGEMENT
│   ├── DataStore.swift               # Central state + persistence
│   │
│   ├── # AI INTEGRATION
│   ├── AIService.swift               # HTTP client for server API
│   │
│   ├── # GOAL VIEWS
│   ├── AddGoalView.swift             # Create goal + generate tasks
│   ├── EditGoalView.swift            # Edit existing goal
│   ├── GoalView.swift                # Display goal details
│   │
│   ├── # SETTINGS
│   ├── PreferencesView.swift         # User scheduling preferences UI
│   ├── BabySettingsView.swift        # Legacy settings (baby info)
│   │
│   ├── # OTHER VIEWS (Legacy)
│   ├── AddFeedView.swift, AddSleepView.swift, AddTaskView.swift
│   ├── EditFeedView.swift, EditSleepView.swift, EditTaskView.swift
│   ├── DonutChartView.swift          # Arc/clock visualization
│   ├── EventListView.swift           # List of day's events
│   └── ...
│
├── server/                           # Node.js Backend
│   ├── package.json
│   ├── server.js                     # Express API with Groq integration
│   ├── .env.example                  # Environment template
│   └── .gitignore
│
└── Dad App.xcodeproj/                # Xcode project
```

---

## Data Models

### GoalEvent

The top-level container for a user's ambition.

```swift
struct GoalEvent: Identifiable, Codable {
    var id: UUID
    var date: Date              // When created
    var deadline: Date?         // Target completion date
    var title: String           // "Launch a SaaS product"
    var taskIds: [UUID]         // Links to TaskEvents
    var milestoneIds: [UUID]    // Links to Milestones
    var isCompleted: Bool
}
```

### Milestone

Intermediate checkpoints between goal start and completion.

```swift
struct Milestone: Identifiable, Codable {
    var id: UUID
    var goalId: UUID            // Parent goal
    var title: String           // "Build MVP"
    var targetDate: Date        // When this should be achieved
    var order: Int              // Sequence (1, 2, 3...)
    var isCompleted: Bool
    var completedDate: Date?
}
```

### TaskEvent

Individual actionable tasks with scheduling info.

```swift
struct TaskEvent: Identifiable, Codable {
    var id: UUID
    var date: Date                    // Actual start time
    var title: String
    var endTime: Date
    var completed: Bool
    var parentGoalId: UUID?           // Link to parent goal
    var orderInGoal: Int?             // Sequence within goal
    var milestoneId: UUID?            // Link to milestone
    var scheduledDate: Date?          // AI-scheduled date
    var estimatedMinutes: Int?        // AI's time estimate
    // ... other fields
}
```

### TaskObservation

Records what happens to tasks for behavioral learning.

```swift
struct TaskObservation: Identifiable, Codable {
    let id: UUID
    let taskId: UUID
    let goalId: UUID?
    let timestamp: Date
    let eventType: ObservationEventType  // .completed, .rescheduled, .edited, .skipped

    // Context
    let dayOfWeek: Int              // 1-7
    let hourOfDay: Int              // 0-23
    let timeBlock: TimeBlock?       // morning/afternoon/evening

    // Completion data
    let estimatedMinutes: Int?
    let actualMinutes: Int?
    let wasOnTime: Bool?

    // Edit/reschedule data
    let previousTitle: String?
    let newTitle: String?
    let previousDate: Date?
    let newDate: Date?
}
```

### UserExecutionProfile

Calculated metrics from observations.

```swift
struct UserExecutionProfile: Codable {
    let overallCompletionRate: Double           // 0.0 - 1.0
    let weightedCompletionRate: Double          // Recent observations weighted higher
    let averageDurationMultiplier: Double       // actual/estimated
    let bestTimeBlock: TimeBlock?
    let worstTimeBlock: TimeBlock?
    let mostProductiveDay: Int?                 // 1-7
    let completionRateByDuration: [String: Double]  // "short", "medium", "long"
    let observationCount: Int

    func toPromptSummary() -> String?           // For AI prompt inclusion
}
```

### UserPreferences

User's stated scheduling preferences.

```swift
struct UserPreferences: Codable {
    var availableHoursPerDay: Double      // e.g., 2.0
    var preferredTaskDurationMinutes: Int // e.g., 30
    var preferredTimeBlocks: [TimeBlock]  // .morning, .afternoon, .evening
    var workDays: [Weekday]               // which days to schedule tasks
}
```

---

## Data Flow

### Creating a Goal

```
1. User enters goal text + deadline in AddGoalView
2. AddGoalView calls AIService.breakdownGoal()
3. AIService sends POST to server with:
   - goal, deadline, currentDate
   - preferences (from DataStore)
   - behavioralProfile (if hasEnoughData)
4. Server builds prompt and calls Groq LLM
5. Server returns { milestones[], tasks[] }
6. AddGoalView creates:
   - Milestone objects (stored in DataStore.milestones)
   - TaskEvent objects (stored in DataStore.taskEvents)
   - GoalEvent linking them all (stored in DataStore.goalEvents)
```

### Behavioral Learning

```
1. User completes/edits/reschedules/skips a task
2. DataStore automatically records TaskObservation
3. Every 5 observations, executionProfile is recalculated
4. Next goal creation includes profile in AI request
5. AI personalizes scheduling based on learned patterns
```

---

## API Documentation

### POST /api/breakdown

Generate milestones and tasks for a goal.

**Request:**

```json
{
  "goal": "Launch a SaaS product",
  "currentDate": "2026-01-07",
  "deadline": "2026-06-01",
  "preferences": {
    "availableHoursPerDay": 2,
    "preferredTaskDurationMinutes": 30,
    "preferredTimeBlocks": ["morning"],
    "workDays": ["monday", "tuesday", "wednesday", "thursday", "friday"]
  },
  "behavioralProfile": "User behavioral patterns:\n- Best time: Morning (85%)\n...",
  "context": "Optional additional context"
}
```

**Response:**

```json
{
  "success": true,
  "goal": "Launch a SaaS product",
  "milestones": [
    {
      "title": "Define Product Vision",
      "targetDate": "2026-01-31",
      "order": 1
    },
    { "title": "Build MVP", "targetDate": "2026-03-15", "order": 2 }
  ],
  "tasks": [
    {
      "title": "Research competitor products",
      "estimatedMinutes": 30,
      "scheduledDate": "2026-01-08",
      "scheduledStartTime": "09:00",
      "milestoneIndex": 0,
      "order": 1
    }
  ]
}
```

### GET /health

Health check endpoint.

**Response:**

```json
{
  "status": "ok",
  "version": "1.3.0",
  "timestamp": "2026-01-07T10:30:00.000Z"
}
```

---

## Setup Instructions

### Prerequisites

- Xcode 15+
- Node.js 18+
- Groq API key (free at https://console.groq.com/keys)

### 1. Server Setup

```bash
cd server
cp .env.example .env
# Edit .env and add your GROQ_API_KEY

npm install
npm run dev
```

Server runs at `http://localhost:3000`

### 2. iOS App Setup

1. Open `Dad App.xcodeproj` in Xcode
2. Ensure `Info.plist` is linked in Build Settings (for ATS exception)
3. Build and run on simulator

**For physical device testing:**

- Find your Mac's IP: `ifconfig | grep "inet " | grep -v 127.0.0.1`
- Update `AIService.swift` baseURL to use your IP instead of localhost

### 3. Test the API

```bash
curl -s -X POST http://localhost:3000/api/breakdown \
  -H "Content-Type: application/json" \
  -d '{"goal": "Learn Spanish", "deadline": "2026-06-01"}' | jq .
```

---

## Implementation Phases

### Phase 1: Context-Aware Scheduling ✅

- AI generates milestones and tasks with actual scheduled dates
- Tasks spread across timeline toward deadline
- Basic preferences (hours/day, time blocks, work days)

### Phase 2: User Preferences UI ✅

- PreferencesView for configuring scheduling preferences
- Preferences persisted and sent with API requests
- AI respects stated preferences

### Phase 3: Behavioral Learning ✅

- TaskObservation tracks completions, edits, reschedules, skips
- UserExecutionProfile calculated from observations
- Exponential decay weighting (recent behavior matters more)
- Profile included in AI prompts when enough data exists (10+ observations)

### Phase 3.5: AI Personalization ✅

- Server includes behavioral profile in LLM prompt
- AI adjusts scheduling based on learned patterns
- Graceful degradation when no profile data exists

---

## Key Files for AI Continuation

If you're an AI picking up development, focus on these files:

| File                         | Purpose                                                      |
| ---------------------------- | ------------------------------------------------------------ |
| `DataStore.swift`            | Central state management, persistence, observation recording |
| `AIService.swift`            | HTTP client for server communication                         |
| `server/server.js`           | Express server with Groq LLM integration                     |
| `AddGoalView.swift`          | Goal creation UI and flow                                    |
| `UserExecutionProfile.swift` | Behavioral metrics calculation                               |

---

## Future Development (Not Yet Implemented)

### Phase 4: Adaptive Replanning

- Automatic plan adjustment when tasks are missed
- Trigger-based replanning (missed 3+ tasks, deadline changed, etc.)
- AI regenerates only affected portions of the plan

### Phase 5: Multi-Goal Orchestration

- Multiple active goals competing for time
- Priority ranking and time allocation
- Conflict detection and resolution

### UI Modernization

- Rename app from "Dad App" to "Ambition"
- Remove baby-tracking features
- New onboarding flow focused on goals
- Profile visualization (show users their patterns)

---

## Environment Variables

### Server (.env)

```
GROQ_API_KEY=gsk_your_key_here
PORT=3000
NODE_ENV=development
```

### iOS (AIService.swift)

```swift
#if DEBUG
return "http://localhost:3000"      // Simulator
// return "http://192.168.1.X:3000" // Physical device
#else
return "https://your-app.railway.app"  // Production
#endif
```

---

## Persistence

All data is stored in **UserDefaults** (iOS):

- `baby` - Baby settings (legacy)
- `events` - General events
- `goalEvents` - Goals
- `taskEvents` - Tasks
- `milestones` - Milestones
- `userPreferences` - Scheduling preferences
- `taskObservations` - Behavioral observations
- `executionProfile` - Calculated metrics

---

## License

Private / Proprietary

---

## Contact

Ash Beech
