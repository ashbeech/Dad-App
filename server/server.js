import express from 'express';
import cors from 'cors';
import Groq from 'groq-sdk';
import dotenv from 'dotenv';

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

// Initialize Groq client
const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

// Phase 2: Improved system prompt with better task distribution
const SYSTEM_PROMPT = `You are an intelligent goal planning assistant. When given a goal with a deadline, you create a realistic plan that spreads work evenly across the available time.

Your job is to break down goals into:
1. MILESTONES: 2-5 major checkpoints, evenly distributed between now and the deadline
2. TASKS: Specific tasks scheduled CLOSE TO their milestone's target date (not all at the start)

CRITICAL SCHEDULING RULES:
- Tasks should be scheduled in the days/weeks LEADING UP TO their milestone target date
- Do NOT frontload all tasks at the beginning
- Spread tasks evenly across the entire timeline
- Each milestone should have tasks scheduled in the 1-2 weeks before its target date
- Later milestones = later scheduled tasks

Example: If Milestone 2 targets March 15, schedule its tasks in late February/early March, NOT in January.

Other rules:
1. Return ONLY valid JSON - no markdown, no explanation
2. Each task: 15-90 minutes, using action verbs (Research, Build, Write, Review, etc.)
3. Be specific and practical
4. Respect the user's daily hour limit and work days
5. Tasks within a milestone should be in logical dependency order

Output format (strict JSON):
{
  "milestones": [
    {"title": "Milestone name", "targetDate": "YYYY-MM-DD", "order": 1}
  ],
  "tasks": [
    {
      "title": "Task description",
      "estimatedMinutes": 30,
      "scheduledDate": "YYYY-MM-DD",
      "scheduledStartTime": "HH:MM",
      "milestoneIndex": 0,
      "order": 1
    }
  ]
}`;

app.post('/api/breakdown', async (req, res) => {
  try {
    const { goal, deadline, currentDate, preferences, behavioralProfile, context } = req.body;
    
    if (!goal || typeof goal !== 'string' || goal.trim().length === 0) {
      return res.status(400).json({ 
        success: false,
        error: 'Goal is required and must be a non-empty string' 
      });
    }

    // Parse preferences with defaults
    const prefs = preferences || {};
    const availableHours = prefs.availableHoursPerDay || 2;
    const preferredDuration = prefs.preferredTaskDurationMinutes || 30;
    const timeBlocks = prefs.preferredTimeBlocks || ['morning'];
    const workDays = prefs.workDays || ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];
    
    // Calculate default start time based on preferred time block
    const getStartTime = (block) => {
      switch (block) {
        case 'morning': return '09:00';
        case 'afternoon': return '13:00';
        case 'evening': return '18:00';
        default: return '09:00';
      }
    };
    const preferredStartTime = getStartTime(timeBlocks[0]);

    // Build the user prompt with all context
    let userPrompt = `Goal: "${goal.trim()}"
Current date: ${currentDate || new Date().toISOString().split('T')[0]}`;

    if (deadline) {
      userPrompt += `\nDeadline: ${deadline}`;
    } else {
      // Default to 30 days if no deadline
      const defaultDeadline = new Date();
      defaultDeadline.setDate(defaultDeadline.getDate() + 30);
      userPrompt += `\nDeadline: ${defaultDeadline.toISOString().split('T')[0]} (default 30 days)`;
    }

    userPrompt += `

User preferences:
- Available hours per day: ${availableHours}
- Preferred task duration: ${preferredDuration} minutes
- Preferred time blocks: ${timeBlocks.join(', ')}
- Work days: ${workDays.join(', ')}
- Preferred start time: ${preferredStartTime}`;

    // Phase 3: Include behavioral profile if provided (learned from user's actual behavior)
    if (behavioralProfile && typeof behavioralProfile === 'string' && behavioralProfile.trim().length > 0) {
      userPrompt += `\n\n${behavioralProfile}

IMPORTANT: Use the behavioral patterns above to personalize this plan:
- Schedule tasks during their most productive times
- Avoid scheduling during their challenging times
- If they tend to take longer than estimated, pad durations accordingly
- If they prefer shorter tasks, break work into smaller chunks`;
    }

    if (context) {
      userPrompt += `\n\nAdditional context: ${context}`;
    }

    userPrompt += `

Create milestones and schedule tasks across the available days. 
Each day should have no more than ${Math.floor(availableHours * 60 / preferredDuration)} tasks.
Return only the JSON object.`;

    const completion = await groq.chat.completions.create({
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: userPrompt }
      ],
      model: 'llama-3.3-70b-versatile',
      temperature: 0.3,
      max_tokens: 2048,  // More tokens for complex plans
      response_format: { type: 'json_object' }
    });

    const responseText = completion.choices[0]?.message?.content;
    
    if (!responseText) {
      throw new Error('Empty response from AI');
    }

    // Parse the JSON response
    let parsed;
    try {
      parsed = JSON.parse(responseText);
    } catch (parseError) {
      console.error('Failed to parse response:', responseText);
      throw new Error('Could not parse AI response as JSON');
    }

    // Extract and normalize milestones
    const milestones = (parsed.milestones || []).map((m, i) => ({
      title: String(m.title || 'Milestone').trim(),
      targetDate: m.targetDate || currentDate,
      order: parseInt(m.order) || (i + 1)
    }));

    // Extract and normalize tasks
    const tasks = (parsed.tasks || []).map((t, i) => ({
      title: String(t.title || 'Untitled task').trim(),
      estimatedMinutes: Math.min(Math.max(parseInt(t.estimatedMinutes) || preferredDuration, 10), 120),
      scheduledDate: t.scheduledDate || currentDate,
      scheduledStartTime: t.scheduledStartTime || preferredStartTime,
      milestoneIndex: parseInt(t.milestoneIndex) ?? 0,
      order: parseInt(t.order) || (i + 1)
    }));

    res.json({
      success: true,
      goal: goal.trim(),
      milestones,
      tasks
    });

  } catch (error) {
    console.error('Error in /api/breakdown:', error);
    
    if (error.message?.includes('API key')) {
      res.status(500).json({ 
        success: false,
        error: 'Server configuration error',
        details: 'Invalid or missing API key'
      });
    } else if (error.message?.includes('rate limit')) {
      res.status(429).json({ 
        success: false,
        error: 'Rate limit exceeded',
        details: 'Please try again in a moment'
      });
    } else {
      res.status(500).json({ 
        success: false,
        error: 'Failed to generate plan',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined
      });
    }
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok',
    version: '1.3.0',  // Phase 3
    timestamp: new Date().toISOString()
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({ 
    name: 'DadTrack API',
    version: '1.3.0',
    phase: 'Phase 3 - Behavioral Learning',
    endpoints: {
      health: 'GET /health',
      breakdown: 'POST /api/breakdown'
    }
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 DadTrack API v1.3.0 (Phase 3 - Behavioral Learning) running on port ${PORT}`);
  console.log(`   Health check: http://localhost:${PORT}/health`);
});
