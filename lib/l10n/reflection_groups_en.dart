import '../models/reflection_group.dart';

/// English reflection prompts, five groups per area. Order is display order
/// and also each prompt's stored id (its index in the flattened list).

const reflectionGroupsPhysicalEn = <ReflectionGroup>[
  ReflectionGroup('Body Now', [
    'How do you feel in your body these days?',
    'Where do you hold tension, and when did you last notice it?',
    'How well did you sleep this week, and what affected it?',
    'What is your body asking for that you keep ignoring?',
    'How would you describe your relationship with your body right now?',
  ]),
  ReflectionGroup('Care & Health', [
    'What do you do regularly to take care of your health?',
    'What check-up or appointment have you been postponing?',
    'What does your usual diet give you, and what does it take away?',
    'How much water, rest and daily movement do you actually get?',
    'What is one small thing that would make your daily care easier?',
  ]),
  ReflectionGroup('Habits & Movement', [
    "What's a physical habit you'd like to build, and what's holding you back?",
    'What kind of movement do you genuinely enjoy?',
    "What habit do you do without thinking that you'd like to change?",
    'What makes you skip exercise, and what has helped before?',
    'What would a realistic week of movement look like for you?',
  ]),
  ReflectionGroup('Energy', [
    'When do you feel most energetic during the day? What brings that on?',
    'What drains your energy the most?',
    'What leaves you feeling recharged after a tiring day?',
    'How do you usually treat tiredness: push through it or listen to it?',
    'When did you last feel strong in your body? What were you doing?',
  ]),
  ReflectionGroup('Strength & Future', [
    'What would you like your body to be able to do in ten years?',
    'What physical limit have you accepted, and which one are you ready to question?',
    'What are you grateful your body does for you every day?',
    'Who or what helps you stay active?',
    'What would taking your body seriously look like this month?',
  ]),
];

const reflectionGroupsPsychologicalEn = <ReflectionGroup>[
  ReflectionGroup('Right Now', [
    "What's weighing on your mind the most right now?",
    'What emotion have you felt most often this week?',
    'What are you avoiding thinking about?',
    'If your mind were a weather report today, what would it say?',
    'What do you need more of right now, and what do you need less of?',
  ]),
  ReflectionGroup('Stress & Coping', [
    'How do you handle stress when it shows up?',
    "What are the first signs that you're getting overwhelmed?",
    'What do you do to cope that helps in the moment but hurts later?',
    'Who or what helps you recover when things get hard?',
    "What's one situation you could stop reacting to and start choosing a response for?",
  ]),
  ReflectionGroup('Thoughts & Patterns', [
    'What recurring thought would you like to let go of?',
    'What story do you keep telling yourself about who you are?',
    'When do you tend to be hardest on yourself?',
    "What would you say to a friend who was thinking what you're thinking?",
    'What belief about yourself has changed in the last few years?',
  ]),
  ReflectionGroup('Calm & Resilience', [
    'What makes you feel calm and centered?',
    'When was the last time you felt truly at peace? What was around you?',
    "What have you gotten through that you once thought you couldn't?",
    'What small ritual could you add to your day to feel more grounded?',
    'What does rest actually look like for you, not just stopping work?',
  ]),
  ReflectionGroup('Growth & Care', [
    'What would you like to understand better about yourself?',
    'What would it mean to be kinder to yourself this month?',
    'What kind of support would you like, and who could you ask?',
    'Which emotion do you find hardest to sit with, and why?',
    'What would your mind look like if it felt a little lighter?',
  ]),
];

const reflectionGroupsProfessionalEn = <ReflectionGroup>[
  ReflectionGroup('Fulfillment', [
    'Do you feel fulfilled in your work? Why or why not?',
    'Which part of your work do you lose track of time in?',
    'What part of your work would you happily stop doing?',
    "What do you tell people about your job, and is it what you feel?",
    'On a good workday, what happened?',
  ]),
  ReflectionGroup('Skills & Learning', [
    "What's the next skill you want to develop?",
    'What are you better at than most people around you?',
    'Who could you learn from, and what would you ask them?',
    'What have you learned recently that surprised you?',
    'What skill, if you had it, would change what you can do?',
  ]),
  ReflectionGroup('Meaning & Impact', [
    'What would make your work feel more meaningful?',
    'Who benefits from what you do?',
    'What would you do if money were not a concern?',
    'Which of your values does your work honour, and which does it ignore?',
    'What would you want to be remembered for at work?',
  ]),
  ReflectionGroup('Direction & Ambition', [
    'Where do you see yourself professionally a year from now?',
    'What opportunity are you hesitating to go for?',
    'What does success mean to you, in your own terms?',
    'What would you change about your role if you could?',
    "What's the next step you could take this month?",
  ]),
  ReflectionGroup('Balance & Environment', [
    'How does your work affect the rest of your life?',
    'How do you feel about the people and culture around you at work?',
    'When did you last say no at work, and what did it cost or give you?',
    'What boundary around your work would you like to set?',
    'What would a sustainable pace look like for you?',
  ]),
];

const reflectionGroupsFinancialEn = <ReflectionGroup>[
  ReflectionGroup('Relationship With Money', [
    "What's your relationship with money like?",
    'What did you learn about money growing up?',
    'What emotion comes up when you check your accounts?',
    'What do you spend on that truly adds value to your life?',
    "What do you spend on that you'd rather not?",
  ]),
  ReflectionGroup('Worries & Risks', [
    'What worries you most about your finances?',
    'Are you avoiding any financial task, and why?',
    'How prepared are you for an unexpected expense?',
    "What debts or obligations weigh on you, and what's the plan?",
    "What would you want to know about money that you don't yet?",
  ]),
  ReflectionGroup('Goals & Plans', [
    "What's one concrete financial goal for the coming months?",
    'How much do you save regularly, and is it enough for what you want?',
    'What big purchase or project are you planning toward?',
    'What habit would improve your finances the most?',
    'How would you like your income to look in three years?',
  ]),
  ReflectionGroup('Security & Freedom', [
    'What would financial security actually feel like for you?',
    'How much is enough for you?',
    'What would you do with more financial freedom?',
    'What does a safety net look like for you?',
    'Where does your sense of security come from other than money?',
  ]),
  ReflectionGroup('Values & Giving', [
    'What does your spending say about what you value?',
    'How do you decide what is worth paying for?',
    'Do you share money with people or causes you care about, and how does it feel?',
    'What would your future self thank you for doing with money now?',
    'Who could you talk to openly about money?',
  ]),
];

const reflectionGroupsPersonalEn = <ReflectionGroup>[
  ReflectionGroup('Self-Knowledge', [
    'What are you learning about yourself lately?',
    'How would you describe yourself in three words, and are they your own words?',
    'What do people misunderstand about you?',
    'What part of yourself do you rarely show?',
    'What are you curious about right now?',
  ]),
  ReflectionGroup('Values', [
    'Which value guides your choices the most?',
    'When did you last act against a value, and what happened?',
    'What would you refuse to compromise on?',
    'Which value would you like to live more fully?',
    'Who do you admire, and what do they stand for?',
  ]),
  ReflectionGroup('Action & Courage', [
    'What would you like to stop putting off?',
    "What would you try if you knew you couldn't fail?",
    'What fear has stopped you recently?',
    'What would be a small first step toward something you want?',
    "What have you outgrown that you're still holding on to?",
  ]),
  ReflectionGroup('Pride & Gratitude', [
    'What are you proud of, even something small?',
    "What's something you handled better than you expected?",
    'What are three things you\'re thankful for today?',
    'What did you overcome that nobody saw?',
    'What would your younger self think of you now?',
  ]),
  ReflectionGroup('Direction', [
    'What kind of person do you want to become?',
    'What do you want more of in your life? Less of?',
    'What does a good day look like for you?',
    "What gift or talent are you not using?",
    'What would you like to be different a year from now?',
  ]),
];

const reflectionGroupsSocialEn = <ReflectionGroup>[
  ReflectionGroup('Time & People', [
    'Who would you like to spend more time with?',
    'Who makes you feel most like yourself?',
    'Who have you lost touch with and would like to reach out to?',
    'How often do you feel lonely, and when?',
    'What kind of company do you need right now?',
  ]),
  ReflectionGroup('Care & Effort', [
    'How do you take care of your most important relationships?',
    'When did you last tell someone what they mean to you?',
    'How do you show up for people in hard times?',
    'What gets in the way of you being a better friend, partner or family member?',
    'What ritual could you start with someone you love?',
  ]),
  ReflectionGroup('Attention & Repair', [
    'Is there a relationship that needs your attention right now?',
    "Is there a conversation you've been avoiding?",
    'What do you need to forgive, or to be forgiven for?',
    'What pattern keeps repeating in your relationships?',
    'When did you last set a boundary with someone, and how did it go?',
  ]),
  ReflectionGroup('Qualities', [
    'What do you really look for in the people around you?',
    'What do you bring to a friendship?',
    'How do you handle disagreement with people you care about?',
    'Which relationships energise you, and which drain you?',
    'Who do you trust completely, and why?',
  ]),
  ReflectionGroup('Belonging', [
    'Where do you feel you belong?',
    'How comfortable are you asking for help?',
    'What community would you like to be part of?',
    'How do you meet new people, and do you want to?',
    "What kind of presence do you want to be in other people's lives?",
  ]),
];

const reflectionGroupsSpiritualEn = <ReflectionGroup>[
  ReflectionGroup('Meaning', [
    'What gives your days meaning?',
    "What do you believe in, even if you can't prove it?",
    'What question about life do you keep returning to?',
    'What would you want your life to say about you?',
    'When did you last feel that your life had a purpose?',
  ]),
  ReflectionGroup('Connection', [
    'When do you feel connected to something bigger than yourself?',
    'What place makes you feel most at peace?',
    'When did you last feel awe?',
    'How do you feel about nature, the universe, or the unknown?',
    'What practice (prayer, walking, silence, art) connects you?',
  ]),
  ReflectionGroup('Inner Peace', [
    'How do you cultivate inner peace?',
    'How much silence is in your day?',
    "What helps you let go of what you can't control?",
    'What do you do when everything feels uncertain?',
    'How do you make peace with loss or endings?',
  ]),
  ReflectionGroup('Authenticity', [
    'What does living authentically mean to you?',
    'Where do you live differently from what you truly believe?',
    'What have you stopped pretending?',
    'What do you need to say yes or no to in order to be yourself?',
    'When do you feel most like your true self?',
  ]),
  ReflectionGroup('Practice & Growth', [
    'What ritual could bring more presence into your week?',
    'What do you want to be more grateful for?',
    'What wisdom would you like to pass on?',
    'How have your beliefs changed over time?',
    'What would a quiet moment each day look like for you?',
  ]),
];

const reflectionGroupsPhilanthropicEn = <ReflectionGroup>[
  ReflectionGroup('Contribution', [
    'How do you contribute to something bigger than yourself?',
    'What do you wish you could change in the world around you?',
    'What kind of difference would you like to make?',
    'What are you already doing that matters to others?',
    "How would your community notice if you weren't there?",
  ]),
  ReflectionGroup('Giving & Helping', [
    'Who have you helped recently, and how did it make you feel?',
    'Who helped you when you needed it?',
    "What's an act of kindness you remember from a stranger?",
    'What stops you from helping more?',
    'What small act of kindness could you do this week?',
  ]),
  ReflectionGroup('Causes', [
    'What cause matters to you, and why?',
    'What injustice makes you angry or sad?',
    'What organisation or person do you admire for their work?',
    'What personal experience shapes the cause you care about?',
    'How could you learn more about this cause?',
  ]),
  ReflectionGroup('Resources', [
    "What could you give — time, skills, energy — that you're not giving yet?",
    'What skill of yours could help a person or group?',
    'How much time could you realistically give each month?',
    'What would you give if money were no object?',
    "Who could you join or support so that you don't have to do it alone?",
  ]),
  ReflectionGroup('Legacy & Values', [
    'What would you like to leave behind for others?',
    'How do you teach or inspire others by example?',
    'How do you balance caring for yourself and caring for others?',
    'What does generosity mean to you beyond money?',
    'What would a kinder world look like in your corner of it?',
  ]),
];
