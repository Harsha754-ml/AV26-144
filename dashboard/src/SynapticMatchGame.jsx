import React, { useState, useEffect, useCallback, useRef } from 'react';
import { Brain, CheckCircle2, RotateCcw, Zap, Timer, Trophy, Flame, Target, Keyboard, Heart, Shield, Skull, Star, Award } from 'lucide-react';

const API_BASE = "http://127.0.0.1:8000";

// ============================================================
// DEMO DATA - Always available for showcase
// ============================================================
const DEMO_FLASHCARDS = [
  { id: "d1", topic_name: "Philosophy: Stoicism", question: "What is the 'Dichotomy of Control' as defined by Epictetus?", answer: "The distinction between things within our power (our judgments, intentions) and things not in our power (external events, others' actions)." },
  { id: "d2", topic_name: "Quantum Mechanics", question: "Define the Heisenberg Uncertainty Principle.", answer: "It is impossible to simultaneously know both the exact position and exact momentum of a particle with arbitrary precision." },
  { id: "d3", topic_name: "React Performance", question: "When should useMemo be preferred over simple memoization?", answer: "When a computation is expensive and its dependencies change infrequently, preventing unnecessary recalculations on every render." },
  { id: "d4", topic_name: "Growth Strategy", question: "Explain the AARRR (Pirate Metrics) framework.", answer: "Acquisition, Activation, Retention, Revenue, Referral — a funnel for measuring SaaS growth at each stage of the user lifecycle." },
  { id: "d5", topic_name: "Neuroscience", question: "What role does the hippocampus play in memory?", answer: "It consolidates short-term memories into long-term memories and is critical for spatial navigation and episodic memory formation." },
  { id: "d6", topic_name: "Distributed Systems", question: "What is the Saga Pattern used for?", answer: "Managing data consistency across microservices by breaking a transaction into a sequence of local transactions with compensating actions for rollback." },
  { id: "d7", topic_name: "Machine Learning", question: "What is the bias-variance tradeoff?", answer: "Bias is error from oversimplified models (underfitting); variance is error from over-complex models (overfitting). The goal is to minimize both." },
  { id: "d8", topic_name: "Operating Systems", question: "What is a deadlock?", answer: "A state where two or more processes are blocked forever, each waiting for a resource held by the other, forming a circular dependency." },
];

// ============================================================
// HELPER: Offline-first sync queue for game results
// Games always work. Results queue in localStorage and sync when server is up.
// ============================================================
const QUEUE_KEY = 'memoryforge_game_queue';

const queueGameResults = (results) => {
  const existing = JSON.parse(localStorage.getItem(QUEUE_KEY) || '[]');
  const updated = [...existing, ...results];
  localStorage.setItem(QUEUE_KEY, JSON.stringify(updated));
  // Try immediate sync
  syncQueue();
};

const syncQueue = async () => {
  const queue = JSON.parse(localStorage.getItem(QUEUE_KEY) || '[]');
  if (queue.length === 0) return;

  const synced = [];
  for (const item of queue) {
    try {
      await fetch(`${API_BASE}/flashcard/review`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ flashcard_id: item.id, result: item.result })
      });
      synced.push(item);
    } catch (e) {
      break; // Server unreachable, stop trying
    }
  }

  if (synced.length > 0) {
    const remaining = queue.slice(synced.length);
    localStorage.setItem(QUEUE_KEY, JSON.stringify(remaining));
    console.log(`✅ Synced ${synced.length} game results. ${remaining.length} pending.`);
  }
};

// Background sync every 10 seconds
setInterval(syncQueue, 10000);

// Send game results — always works offline, syncs when connected
const sendGameResults = (results) => {
  queueGameResults(results);
};

// ============================================================
// GAME 1: SYNAPTIC MATCH (Memory Card Matching)
// ============================================================
const MatchGame = ({ flashcards }) => {
  const [cards, setCards] = useState([]);
  const [flippedIndices, setFlippedIndices] = useState([]);
  const [matchedIds, setMatchedIds] = useState(new Set());
  const [moves, setMoves] = useState(0);
  const [timer, setTimer] = useState(0);
  const [isRunning, setIsRunning] = useState(false);
  const [bestScore, setBestScore] = useState(null);
  const [gameResults, setGameResults] = useState([]);

  const initGame = useCallback(() => {
    const selected = flashcards.slice(0, 6);
    const gameCards = [];
    selected.forEach((fc) => {
      gameCards.push({ id: fc.id, type: 'question', text: fc.question });
      gameCards.push({ id: fc.id, type: 'answer', text: fc.answer || 'Answer hidden...' });
    });
    gameCards.sort(() => Math.random() - 0.5);
    setCards(gameCards);
    setFlippedIndices([]);
    setMatchedIds(new Set());
    setMoves(0);
    setTimer(0);
    setIsRunning(false);
    setGameResults([]);
  }, [flashcards]);

  useEffect(() => { initGame(); }, [initGame]);

  useEffect(() => {
    let interval;
    if (isRunning) interval = setInterval(() => setTimer(t => t + 1), 1000);
    return () => clearInterval(interval);
  }, [isRunning]);

  const handleCardClick = (index) => {
    if (flippedIndices.includes(index) || matchedIds.has(cards[index].id) || flippedIndices.length === 2) return;
    if (!isRunning) setIsRunning(true);

    const newFlipped = [...flippedIndices, index];
    setFlippedIndices(newFlipped);

    if (newFlipped.length === 2) {
      setMoves(m => m + 1);
      const firstCard = cards[newFlipped[0]];
      const secondCard = cards[newFlipped[1]];

      if (firstCard.id === secondCard.id && firstCard.type !== secondCard.type) {
        setTimeout(() => {
          const newMatched = new Set(matchedIds);
          newMatched.add(firstCard.id);
          setMatchedIds(newMatched);
          setFlippedIndices([]);
          setGameResults(prev => [...prev, { id: firstCard.id, result: 'remembered' }]);
          if (newMatched.size === Math.min(flashcards.length, 6)) {
            setIsRunning(false);
            const score = moves + 1;
            if (!bestScore || score < bestScore) setBestScore(score);
            // Send results - matched = remembered
            sendGameResults([...gameResults, { id: firstCard.id, result: 'remembered' }]);
          }
        }, 500);
      } else {
        setTimeout(() => setFlippedIndices([]), 1200);
      }
    }
  };

  const isComplete = matchedIds.size === Math.min(flashcards.length, 6);
  const formatTime = (s) => `${Math.floor(s/60)}:${(s%60).toString().padStart(2,'0')}`;

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between bg-[#0f0f11] rounded-3xl p-6 border border-white/5">
        <div className="flex items-center gap-8">
          <div className="flex items-center gap-3">
            <Timer className="w-5 h-5 text-[#c5a059]" />
            <span className="text-2xl font-black text-[#f4f1ea] font-mono">{formatTime(timer)}</span>
          </div>
          <div className="flex items-center gap-3">
            <Target className="w-5 h-5 text-[#8da290]" />
            <span className="text-2xl font-black text-[#f4f1ea]">{moves} <span className="text-sm text-slate-500">moves</span></span>
          </div>
        </div>
        <div className="flex items-center gap-4">
          {bestScore && (
            <div className="flex items-center gap-2 px-4 py-2 bg-[#c5a059]/10 rounded-2xl border border-[#c5a059]/20">
              <Trophy className="w-4 h-4 text-[#c5a059]" />
              <span className="text-xs font-black text-[#c5a059]">BEST: {bestScore}</span>
            </div>
          )}
          <button onClick={initGame} className="p-3 bg-white/5 rounded-2xl hover:bg-white/10 transition-all border border-white/5">
            <RotateCcw className="w-5 h-5 text-slate-400" />
          </button>
        </div>
      </div>

      {isComplete ? (
        <div className="py-20 flex flex-col items-center justify-center text-center">
          <div className="w-28 h-28 bg-[#c5a059]/20 rounded-full flex items-center justify-center mb-8 border border-[#c5a059]/50 shadow-[0_0_60px_rgba(197,160,89,0.3)]">
            <CheckCircle2 className="w-14 h-14 text-[#c5a059]" />
          </div>
          <h4 className="text-5xl font-black text-[#f4f1ea] font-serif mb-3">Neural Link Established</h4>
          <p className="text-[#8da290] mb-2 font-serif italic text-lg">Completed in {moves} moves &bull; {formatTime(timer)}</p>
          <p className="text-slate-500 text-sm mb-10">All matched cards marked as &quot;remembered&quot; — stability boosted.</p>
          <button onClick={initGame} className="flex items-center gap-3 px-10 py-5 bg-[#c5a059] text-black font-black uppercase text-xs tracking-widest rounded-full hover:bg-white transition-all hover:scale-105 shadow-xl">
            <RotateCcw className="w-4 h-4" /> Play Again
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-5">
          {cards.map((card, index) => {
            const isFlipped = flippedIndices.includes(index) || matchedIds.has(card.id);
            const isMatched = matchedIds.has(card.id);
            return (
              <div key={index} onClick={() => handleCardClick(index)} className="h-44 cursor-pointer group perspective-1000">
                <div className={`relative w-full h-full transition-transform duration-500 preserve-3d ${isFlipped ? '[transform:rotateY(180deg)]' : ''}`}>
                  <div className={`absolute w-full h-full backface-hidden bg-[#0a0a0b] rounded-3xl border-2 ${flippedIndices.length === 2 ? 'border-white/5' : 'border-white/10 group-hover:border-[#c5a059]/40'} flex items-center justify-center shadow-lg transition-all`}>
                    <Brain className="w-8 h-8 text-white/10 group-hover:text-white/20 transition-colors" />
                  </div>
                  <div className={`absolute w-full h-full backface-hidden [transform:rotateY(180deg)] rounded-3xl p-5 border-2 flex items-center justify-center text-center shadow-2xl ${isMatched ? 'bg-[#c5a059]/10 border-[#c5a059]/40 text-[#c5a059]' : 'bg-[#1a1a1c] border-[#8da290]/30 text-[#f4f1ea]'}`}>
                    <span className="text-[11px] font-serif font-medium leading-relaxed line-clamp-5">{card.text}</span>
                    {isMatched && <CheckCircle2 className="absolute top-3 right-3 w-4 h-4 text-[#c5a059]" />}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

// ============================================================
// GAME 2: SPEED RECALL (Timed Quiz - rate your recall)
// ============================================================
const SpeedRecall = ({ flashcards }) => {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [showAnswer, setShowAnswer] = useState(false);
  const [score, setScore] = useState({ remembered: 0, forgot: 0 });
  const [timer, setTimer] = useState(0);
  const [isRunning, setIsRunning] = useState(false);
  const [isComplete, setIsComplete] = useState(false);
  const [streak, setStreak] = useState(0);
  const [maxStreak, setMaxStreak] = useState(0);
  const [results, setResults] = useState([]);

  useEffect(() => {
    let interval;
    if (isRunning) interval = setInterval(() => setTimer(t => t + 1), 1000);
    return () => clearInterval(interval);
  }, [isRunning]);

  const startGame = () => {
    setCurrentIndex(0);
    setShowAnswer(false);
    setScore({ remembered: 0, forgot: 0 });
    setTimer(0);
    setIsRunning(true);
    setIsComplete(false);
    setStreak(0);
    setMaxStreak(0);
    setResults([]);
  };

  const handleResult = (result) => {
    const current = flashcards[currentIndex];
    const newResults = [...results, { id: current.id, result }];
    setResults(newResults);

    if (result === 'remembered') {
      setScore(s => ({ ...s, remembered: s.remembered + 1 }));
      setStreak(s => { const n = s + 1; if (n > maxStreak) setMaxStreak(n); return n; });
    } else {
      setScore(s => ({ ...s, forgot: s.forgot + 1 }));
      setStreak(0);
    }

    if (currentIndex + 1 >= flashcards.length) {
      setIsComplete(true);
      setIsRunning(false);
      // Send all results to backend - affects notifications
      sendGameResults(newResults);
    } else {
      setCurrentIndex(i => i + 1);
      setShowAnswer(false);
    }
  };

  const formatTime = (s) => `${Math.floor(s/60)}:${(s%60).toString().padStart(2,'0')}`;
  const accuracy = score.remembered + score.forgot > 0 ? Math.round((score.remembered / (score.remembered + score.forgot)) * 100) : 0;

  if (!isRunning && !isComplete) {
    return (
      <div className="flex flex-col items-center justify-center py-20 text-center">
        <div className="w-24 h-24 bg-[#c5a059]/10 rounded-full flex items-center justify-center mb-8 border border-[#c5a059]/20">
          <Zap className="w-12 h-12 text-[#c5a059]" />
        </div>
        <h3 className="text-4xl font-black text-[#f4f1ea] font-serif mb-3">Speed Recall</h3>
        <p className="text-[#8da290] font-serif italic text-lg mb-2">Test your memory under pressure.</p>
        <p className="text-slate-500 text-sm mb-10 max-w-md">Cards appear one by one. Reveal the answer, then rate your recall honestly. Poor scores trigger revision notifications.</p>
        <button onClick={startGame} className="flex items-center gap-3 px-12 py-5 bg-[#c5a059] text-black font-black uppercase text-xs tracking-widest rounded-full hover:bg-white transition-all hover:scale-105 shadow-xl">
          <Zap className="w-5 h-5" /> Begin Protocol
        </button>
      </div>
    );
  }

  if (isComplete) {
    return (
      <div className="flex flex-col items-center justify-center py-16 text-center">
        <div className="w-28 h-28 bg-[#c5a059]/20 rounded-full flex items-center justify-center mb-8 border border-[#c5a059]/50 shadow-[0_0_60px_rgba(197,160,89,0.3)]">
          <Trophy className="w-14 h-14 text-[#c5a059]" />
        </div>
        <h4 className="text-5xl font-black text-[#f4f1ea] font-serif mb-4">Protocol Complete</h4>
        <p className="text-[#8da290] font-serif italic text-lg mb-2">Finished in {formatTime(timer)}</p>
        <p className="text-slate-500 text-sm mb-10">{score.forgot > 0 ? `${score.forgot} card(s) marked "forgot" — revision notifications scheduled.` : 'Perfect recall! Stability boosted for all cards.'}</p>
        <div className="grid grid-cols-3 gap-6 mb-12 w-full max-w-lg">
          <div className="bg-[#0f0f11] rounded-3xl p-6 border border-white/5 text-center">
            <p className="text-4xl font-black text-[#8da290]">{accuracy}%</p>
            <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest mt-2">Accuracy</p>
          </div>
          <div className="bg-[#0f0f11] rounded-3xl p-6 border border-white/5 text-center">
            <p className="text-4xl font-black text-[#c5a059]">{maxStreak}</p>
            <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest mt-2">Max Streak</p>
          </div>
          <div className="bg-[#0f0f11] rounded-3xl p-6 border border-white/5 text-center">
            <p className="text-4xl font-black text-[#f4f1ea] font-mono">{formatTime(timer)}</p>
            <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest mt-2">Time</p>
          </div>
        </div>
        <button onClick={startGame} className="flex items-center gap-3 px-10 py-5 bg-[#c5a059] text-black font-black uppercase text-xs tracking-widest rounded-full hover:bg-white transition-all hover:scale-105 shadow-xl">
          <RotateCcw className="w-4 h-4" /> Try Again
        </button>
      </div>
    );
  }

  const current = flashcards[currentIndex];
  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between bg-[#0f0f11] rounded-3xl p-6 border border-white/5">
        <div className="flex items-center gap-6">
          <div className="flex items-center gap-2">
            <Timer className="w-4 h-4 text-[#c5a059]" />
            <span className="text-xl font-black text-[#f4f1ea] font-mono">{formatTime(timer)}</span>
          </div>
          {streak > 1 && (
            <div className="flex items-center gap-2 px-3 py-1.5 bg-orange-500/10 rounded-xl border border-orange-500/20 animate-pulse">
              <Flame className="w-4 h-4 text-orange-400" />
              <span className="text-xs font-black text-orange-400">{streak} STREAK</span>
            </div>
          )}
        </div>
        <span className="text-sm font-black text-slate-500">{currentIndex + 1} / {flashcards.length}</span>
      </div>
      <div className="w-full h-2 bg-white/5 rounded-full overflow-hidden">
        <div className="h-full bg-gradient-to-r from-[#c5a059] to-[#8da290] rounded-full transition-all duration-500" style={{ width: `${((currentIndex) / flashcards.length) * 100}%` }} />
      </div>
      <div className="bg-[#0f0f11] rounded-[3rem] p-12 border border-white/5 min-h-[400px] flex flex-col items-center justify-center text-center relative overflow-hidden">
        <span className="text-[10px] font-black text-[#c5a059] uppercase tracking-[0.3em] mb-6">{current.topic_name}</span>
        <h3 className="text-2xl font-serif text-[#f4f1ea] leading-relaxed mb-10 max-w-2xl">{current.question}</h3>
        {showAnswer ? (
          <div className="space-y-8 w-full max-w-2xl">
            <div className="p-8 bg-[#8da290]/10 rounded-3xl border border-[#8da290]/20">
              <p className="text-[#8da290] font-serif italic text-lg leading-relaxed">{current.answer}</p>
            </div>
            <div className="flex items-center justify-center gap-4">
              <button onClick={() => handleResult('remembered')} className="flex items-center gap-3 px-8 py-4 bg-[#8da290] text-black font-black uppercase text-xs tracking-widest rounded-full hover:bg-[#a8c4ab] transition-all hover:scale-105">
                <CheckCircle2 className="w-4 h-4" /> Remembered
              </button>
              <button onClick={() => handleResult('forgot')} className="flex items-center gap-3 px-8 py-4 bg-rose-500/20 text-rose-400 font-black uppercase text-xs tracking-widest rounded-full border border-rose-500/30 hover:bg-rose-500/30 transition-all hover:scale-105">
                <Skull className="w-4 h-4" /> Forgot
              </button>
            </div>
          </div>
        ) : (
          <button onClick={() => setShowAnswer(true)} className="flex items-center gap-3 px-10 py-5 bg-[#c5a059] text-black font-black uppercase text-xs tracking-widest rounded-full hover:bg-white transition-all hover:scale-105 shadow-xl">
            Reveal Answer
          </button>
        )}
      </div>
    </div>
  );
};

// ============================================================
// GAME 3: TYPE CHALLENGE (Type the answer from memory)
// ============================================================
const TypeChallenge = ({ flashcards }) => {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [userInput, setUserInput] = useState('');
  const [isRunning, setIsRunning] = useState(false);
  const [isComplete, setIsComplete] = useState(false);
  const [timer, setTimer] = useState(0);
  const [scores, setScores] = useState([]);
  const [showFeedback, setShowFeedback] = useState(null);
  const [results, setResults] = useState([]);
  const inputRef = useRef(null);

  useEffect(() => {
    let interval;
    if (isRunning) interval = setInterval(() => setTimer(t => t + 1), 1000);
    return () => clearInterval(interval);
  }, [isRunning]);

  const startGame = () => {
    setCurrentIndex(0);
    setUserInput('');
    setIsRunning(true);
    setIsComplete(false);
    setTimer(0);
    setScores([]);
    setShowFeedback(null);
    setResults([]);
    setTimeout(() => inputRef.current?.focus(), 100);
  };

  const calculateSimilarity = (input, answer) => {
    const a = input.toLowerCase().trim();
    const b = answer.toLowerCase().trim();
    if (a === b) return 100;
    const aWords = new Set(a.split(/\s+/));
    const bWords = new Set(b.split(/\s+/));
    let matches = 0;
    for (const word of aWords) {
      if (bWords.has(word)) matches++;
    }
    return Math.round((matches / Math.max(bWords.size, 1)) * 100);
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    const current = flashcards[currentIndex];
    const similarity = calculateSimilarity(userInput, current.answer);
    const passed = similarity >= 40;
    const result = passed ? 'remembered' : 'forgot';
    
    setScores(prev => [...prev, { similarity, passed }]);
    setResults(prev => [...prev, { id: current.id, result }]);
    setShowFeedback({ similarity, passed, correctAnswer: current.answer });

    setTimeout(() => {
      if (currentIndex + 1 >= flashcards.length) {
        setIsComplete(true);
        setIsRunning(false);
        sendGameResults([...results, { id: current.id, result }]);
      } else {
        setCurrentIndex(i => i + 1);
        setUserInput('');
        setShowFeedback(null);
        setTimeout(() => inputRef.current?.focus(), 100);
      }
    }, 2500);
  };

  const handleSkip = () => {
    const current = flashcards[currentIndex];
    setResults(prev => [...prev, { id: current.id, result: 'forgot' }]);
    setScores(prev => [...prev, { similarity: 0, passed: false }]);
    
    if (currentIndex + 1 >= flashcards.length) {
      setIsComplete(true);
      setIsRunning(false);
      sendGameResults([...results, { id: current.id, result: 'forgot' }]);
    } else {
      setCurrentIndex(i => i + 1);
      setUserInput('');
      setShowFeedback(null);
      setTimeout(() => inputRef.current?.focus(), 100);
    }
  };

  const formatTime = (s) => `${Math.floor(s/60)}:${(s%60).toString().padStart(2,'0')}`;

  if (!isRunning && !isComplete) {
    return (
      <div className="flex flex-col items-center justify-center py-20 text-center">
        <div className="w-24 h-24 bg-[#c5a059]/10 rounded-full flex items-center justify-center mb-8 border border-[#c5a059]/20">
          <Keyboard className="w-12 h-12 text-[#c5a059]" />
        </div>
        <h3 className="text-4xl font-black text-[#f4f1ea] font-serif mb-3">Type Challenge</h3>
        <p className="text-[#8da290] font-serif italic text-lg mb-2">Type what you remember. No peeking.</p>
        <p className="text-slate-500 text-sm mb-10 max-w-md">You'll see the question — type your best answer from memory. 40%+ keyword match = pass. Failed cards get flagged for revision.</p>
        <button onClick={startGame} className="flex items-center gap-3 px-12 py-5 bg-[#c5a059] text-black font-black uppercase text-xs tracking-widest rounded-full hover:bg-white transition-all hover:scale-105 shadow-xl">
          <Keyboard className="w-5 h-5" /> Start Typing
        </button>
      </div>
    );
  }

  if (isComplete) {
    const passed = scores.filter(s => s.passed).length;
    const failed = scores.filter(s => !s.passed).length;
    const avgSimilarity = scores.length > 0 ? Math.round(scores.reduce((a, b) => a + b.similarity, 0) / scores.length) : 0;
    return (
      <div className="flex flex-col items-center justify-center py-16 text-center">
        <div className="w-28 h-28 bg-[#c5a059]/20 rounded-full flex items-center justify-center mb-8 border border-[#c5a059]/50 shadow-[0_0_60px_rgba(197,160,89,0.3)]">
          <Award className="w-14 h-14 text-[#c5a059]" />
        </div>
        <h4 className="text-5xl font-black text-[#f4f1ea] font-serif mb-4">Challenge Complete</h4>
        <p className="text-[#8da290] font-serif italic text-lg mb-2">Finished in {formatTime(timer)}</p>
        <p className="text-slate-500 text-sm mb-10">{failed > 0 ? `${failed} card(s) below threshold — revision notifications triggered.` : 'All answers matched! Memory reinforced.'}</p>
        <div className="grid grid-cols-3 gap-6 mb-12 w-full max-w-lg">
          <div className="bg-[#0f0f11] rounded-3xl p-6 border border-white/5 text-center">
            <p className="text-4xl font-black text-[#8da290]">{passed}/{flashcards.length}</p>
            <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest mt-2">Passed</p>
          </div>
          <div className="bg-[#0f0f11] rounded-3xl p-6 border border-white/5 text-center">
            <p className="text-4xl font-black text-[#c5a059]">{avgSimilarity}%</p>
            <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest mt-2">Avg Match</p>
          </div>
          <div className="bg-[#0f0f11] rounded-3xl p-6 border border-white/5 text-center">
            <p className="text-4xl font-black text-[#f4f1ea] font-mono">{formatTime(timer)}</p>
            <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest mt-2">Time</p>
          </div>
        </div>
        <button onClick={startGame} className="flex items-center gap-3 px-10 py-5 bg-[#c5a059] text-black font-black uppercase text-xs tracking-widest rounded-full hover:bg-white transition-all hover:scale-105 shadow-xl">
          <RotateCcw className="w-4 h-4" /> Try Again
        </button>
      </div>
    );
  }

  const current = flashcards[currentIndex];
  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between bg-[#0f0f11] rounded-3xl p-6 border border-white/5">
        <div className="flex items-center gap-6">
          <div className="flex items-center gap-2">
            <Timer className="w-4 h-4 text-[#c5a059]" />
            <span className="text-xl font-black text-[#f4f1ea] font-mono">{formatTime(timer)}</span>
          </div>
        </div>
        <span className="text-sm font-black text-slate-500">{currentIndex + 1} / {flashcards.length}</span>
      </div>
      <div className="w-full h-2 bg-white/5 rounded-full overflow-hidden">
        <div className="h-full bg-gradient-to-r from-[#c5a059] to-[#8da290] rounded-full transition-all duration-500" style={{ width: `${((currentIndex) / flashcards.length) * 100}%` }} />
      </div>
      <div className="bg-[#0f0f11] rounded-[3rem] p-12 border border-white/5 min-h-[400px] flex flex-col items-center justify-center text-center relative overflow-hidden">
        <span className="text-[10px] font-black text-[#c5a059] uppercase tracking-[0.3em] mb-6">{current.topic_name}</span>
        <h3 className="text-2xl font-serif text-[#f4f1ea] leading-relaxed mb-10 max-w-2xl">{current.question}</h3>
        
        {showFeedback ? (
          <div className={`p-8 rounded-3xl border w-full max-w-2xl ${showFeedback.passed ? 'bg-[#8da290]/10 border-[#8da290]/30' : 'bg-rose-500/10 border-rose-500/30'}`}>
            <div className="flex items-center justify-center gap-3 mb-4">
              {showFeedback.passed ? <CheckCircle2 className="w-6 h-6 text-[#8da290]" /> : <Skull className="w-6 h-6 text-rose-400" />}
              <span className={`text-lg font-black ${showFeedback.passed ? 'text-[#8da290]' : 'text-rose-400'}`}>{showFeedback.similarity}% Match</span>
            </div>
            <p className="text-slate-400 text-sm font-serif italic">{showFeedback.correctAnswer}</p>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="w-full max-w-2xl space-y-6">
            <textarea
              ref={inputRef}
              value={userInput}
              onChange={(e) => setUserInput(e.target.value)}
              placeholder="Type your answer from memory..."
              className="w-full h-32 bg-[#0a0a0b] border border-white/10 rounded-3xl p-6 text-[#f4f1ea] placeholder-slate-700 font-serif resize-none focus:border-[#c5a059]/30 outline-none"
            />
            <div className="flex items-center justify-center gap-4">
              <button type="submit" disabled={!userInput.trim()} className="flex items-center gap-3 px-8 py-4 bg-[#c5a059] text-black font-black uppercase text-xs tracking-widest rounded-full hover:bg-white transition-all disabled:opacity-30 disabled:cursor-not-allowed">
                Submit Answer
              </button>
              <button type="button" onClick={handleSkip} className="flex items-center gap-3 px-6 py-4 bg-white/5 text-slate-400 font-black uppercase text-xs tracking-widest rounded-full border border-white/10 hover:bg-white/10 transition-all">
                Skip
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
};

// ============================================================
// GAME 4: SURVIVAL MODE (Endless until you fail 3 times)
// ============================================================
const SurvivalMode = ({ flashcards }) => {
  const [shuffled, setShuffled] = useState([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [showAnswer, setShowAnswer] = useState(false);
  const [lives, setLives] = useState(3);
  const [score, setScore] = useState(0);
  const [isRunning, setIsRunning] = useState(false);
  const [isComplete, setIsComplete] = useState(false);
  const [timer, setTimer] = useState(0);
  const [highScore, setHighScore] = useState(0);
  const [streak, setStreak] = useState(0);
  const [results, setResults] = useState([]);

  useEffect(() => {
    let interval;
    if (isRunning) interval = setInterval(() => setTimer(t => t + 1), 1000);
    return () => clearInterval(interval);
  }, [isRunning]);

  const startGame = () => {
    // Shuffle and repeat cards for endless feel
    const doubled = [...flashcards, ...flashcards, ...flashcards].sort(() => Math.random() - 0.5);
    setShuffled(doubled);
    setCurrentIndex(0);
    setShowAnswer(false);
    setLives(3);
    setScore(0);
    setIsRunning(true);
    setIsComplete(false);
    setTimer(0);
    setStreak(0);
    setResults([]);
  };

  const handleResult = (result) => {
    const current = shuffled[currentIndex];
    const newResults = [...results, { id: current.id, result }];
    setResults(newResults);

    if (result === 'remembered') {
      setScore(s => s + (1 + Math.floor(streak / 3))); // Bonus points for streaks
      setStreak(s => s + 1);
    } else {
      const newLives = lives - 1;
      setLives(newLives);
      setStreak(0);
      if (newLives <= 0) {
        setIsComplete(true);
        setIsRunning(false);
        if (score > highScore) setHighScore(score);
        sendGameResults(newResults);
        return;
      }
    }

    if (currentIndex + 1 >= shuffled.length) {
      // Reshuffle for infinite mode
      const doubled = [...flashcards, ...flashcards, ...flashcards].sort(() => Math.random() - 0.5);
      setShuffled(doubled);
      setCurrentIndex(0);
    } else {
      setCurrentIndex(i => i + 1);
    }
    setShowAnswer(false);
  };

  const formatTime = (s) => `${Math.floor(s/60)}:${(s%60).toString().padStart(2,'0')}`;

  if (!isRunning && !isComplete) {
    return (
      <div className="flex flex-col items-center justify-center py-20 text-center">
        <div className="w-24 h-24 bg-rose-500/10 rounded-full flex items-center justify-center mb-8 border border-rose-500/20">
          <Skull className="w-12 h-12 text-rose-400" />
        </div>
        <h3 className="text-4xl font-black text-[#f4f1ea] font-serif mb-3">Survival Mode</h3>
        <p className="text-[#8da290] font-serif italic text-lg mb-2">How long can you last?</p>
        <p className="text-slate-500 text-sm mb-10 max-w-md">You have 3 lives. Each &quot;forgot&quot; costs a life. Streaks give bonus points. Cards you fail get flagged for urgent revision.</p>
        <div className="flex items-center gap-3 mb-10">
          {[1,2,3].map(i => <Heart key={i} className="w-8 h-8 text-rose-400 fill-rose-400" />)}
        </div>
        {highScore > 0 && (
          <div className="flex items-center gap-2 px-4 py-2 bg-[#c5a059]/10 rounded-2xl border border-[#c5a059]/20 mb-8">
            <Trophy className="w-4 h-4 text-[#c5a059]" />
            <span className="text-xs font-black text-[#c5a059]">HIGH SCORE: {highScore}</span>
          </div>
        )}
        <button onClick={startGame} className="flex items-center gap-3 px-12 py-5 bg-rose-500 text-white font-black uppercase text-xs tracking-widest rounded-full hover:bg-rose-400 transition-all hover:scale-105 shadow-xl">
          <Skull className="w-5 h-5" /> Enter Arena
        </button>
      </div>
    );
  }

  if (isComplete) {
    const forgot = results.filter(r => r.result === 'forgot').length;
    return (
      <div className="flex flex-col items-center justify-center py-16 text-center">
        <div className="w-28 h-28 bg-rose-500/20 rounded-full flex items-center justify-center mb-8 border border-rose-500/50">
          <Skull className="w-14 h-14 text-rose-400" />
        </div>
        <h4 className="text-5xl font-black text-[#f4f1ea] font-serif mb-4">Game Over</h4>
        <p className="text-rose-400 font-serif italic text-lg mb-2">You survived {formatTime(timer)}</p>
        <p className="text-slate-500 text-sm mb-10">{forgot} card(s) marked as forgotten — revision notifications triggered for weak areas.</p>
        <div className="grid grid-cols-3 gap-6 mb-12 w-full max-w-lg">
          <div className="bg-[#0f0f11] rounded-3xl p-6 border border-white/5 text-center">
            <p className="text-4xl font-black text-[#c5a059]">{score}</p>
            <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest mt-2">Score</p>
          </div>
          <div className="bg-[#0f0f11] rounded-3xl p-6 border border-white/5 text-center">
            <p className="text-4xl font-black text-[#8da290]">{results.filter(r => r.result === 'remembered').length}</p>
            <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest mt-2">Recalled</p>
          </div>
          <div className="bg-[#0f0f11] rounded-3xl p-6 border border-white/5 text-center">
            <p className="text-4xl font-black text-[#f4f1ea] font-mono">{formatTime(timer)}</p>
            <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest mt-2">Survived</p>
          </div>
        </div>
        <button onClick={startGame} className="flex items-center gap-3 px-10 py-5 bg-rose-500 text-white font-black uppercase text-xs tracking-widest rounded-full hover:bg-rose-400 transition-all hover:scale-105 shadow-xl">
          <RotateCcw className="w-4 h-4" /> Try Again
        </button>
      </div>
    );
  }

  const current = shuffled[currentIndex];
  if (!current) return null;

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between bg-[#0f0f11] rounded-3xl p-6 border border-white/5">
        <div className="flex items-center gap-6">
          <div className="flex items-center gap-2">
            {[...Array(3)].map((_, i) => (
              <Heart key={i} className={`w-5 h-5 ${i < lives ? 'text-rose-400 fill-rose-400' : 'text-slate-800'}`} />
            ))}
          </div>
          <div className="flex items-center gap-2">
            <Star className="w-4 h-4 text-[#c5a059]" />
            <span className="text-xl font-black text-[#c5a059]">{score}</span>
          </div>
          {streak > 2 && (
            <div className="flex items-center gap-2 px-3 py-1.5 bg-orange-500/10 rounded-xl border border-orange-500/20 animate-pulse">
              <Flame className="w-4 h-4 text-orange-400" />
              <span className="text-xs font-black text-orange-400">x{1 + Math.floor(streak / 3)}</span>
            </div>
          )}
        </div>
        <span className="text-sm font-black text-slate-500 font-mono">{formatTime(timer)}</span>
      </div>

      <div className="bg-[#0f0f11] rounded-[3rem] p-12 border border-white/5 min-h-[400px] flex flex-col items-center justify-center text-center relative overflow-hidden">
        <span className="text-[10px] font-black text-[#c5a059] uppercase tracking-[0.3em] mb-6">{current.topic_name}</span>
        <h3 className="text-2xl font-serif text-[#f4f1ea] leading-relaxed mb-10 max-w-2xl">{current.question}</h3>
        {showAnswer ? (
          <div className="space-y-8 w-full max-w-2xl">
            <div className="p-8 bg-[#8da290]/10 rounded-3xl border border-[#8da290]/20">
              <p className="text-[#8da290] font-serif italic text-lg leading-relaxed">{current.answer}</p>
            </div>
            <div className="flex items-center justify-center gap-4">
              <button onClick={() => handleResult('remembered')} className="flex items-center gap-3 px-8 py-4 bg-[#8da290] text-black font-black uppercase text-xs tracking-widest rounded-full hover:bg-[#a8c4ab] transition-all hover:scale-105">
                <CheckCircle2 className="w-4 h-4" /> Got It
              </button>
              <button onClick={() => handleResult('forgot')} className="flex items-center gap-3 px-8 py-4 bg-rose-500/20 text-rose-400 font-black uppercase text-xs tracking-widest rounded-full border border-rose-500/30 hover:bg-rose-500/30 transition-all hover:scale-105">
                <Heart className="w-4 h-4" /> Lost (-1 Life)
              </button>
            </div>
          </div>
        ) : (
          <button onClick={() => setShowAnswer(true)} className="flex items-center gap-3 px-10 py-5 bg-[#c5a059] text-black font-black uppercase text-xs tracking-widest rounded-full hover:bg-white transition-all hover:scale-105 shadow-xl">
            Reveal Answer
          </button>
        )}
      </div>
    </div>
  );
};

// ============================================================
// MAIN GAME MODE COMPONENT
// ============================================================
const SynapticMatchGame = ({ flashcards }) => {
  const [activeGame, setActiveGame] = useState('match');
  
  // Use real flashcards — only fall back to demo if nothing available
  const gameCards = flashcards && flashcards.length > 0 ? flashcards : DEMO_FLASHCARDS;

  const games = [
    { id: 'match', label: 'MATCH', icon: Brain, desc: 'Pair questions with answers' },
    { id: 'speed', label: 'SPEED', icon: Zap, desc: 'Timed recall quiz' },
    { id: 'type', label: 'TYPE', icon: Keyboard, desc: 'Write from memory' },
    { id: 'survival', label: 'SURVIVAL', icon: Skull, desc: '3 lives, endless cards' },
  ];

  return (
    <div className="space-y-10">
      {/* Game Mode Header */}
      <div className="flex flex-col md:flex-row md:items-end justify-between gap-8">
        <div>
          <div className="flex items-center gap-3 text-[#c5a059] mb-4">
            <Brain className="w-5 h-5" />
            <span className="text-[11px] font-black uppercase tracking-[0.3em]">Game Mode</span>
          </div>
          <h2 className="text-5xl font-black text-[#f4f1ea] font-serif tracking-tighter">Cognitive <span className="text-[#8da290] italic">Arena.</span></h2>
          <p className="text-slate-500 font-serif italic mt-3">Play games to reinforce memory. Poor scores trigger revision notifications.</p>
        </div>
      </div>

      {/* Game Selector - 4 games */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {games.map((game) => (
          <button
            key={game.id}
            onClick={() => setActiveGame(game.id)}
            className={`flex flex-col items-center gap-3 p-6 rounded-3xl border transition-all ${
              activeGame === game.id 
                ? 'bg-[#c5a059]/10 border-[#c5a059]/30 shadow-[0_0_30px_rgba(197,160,89,0.1)]' 
                : 'bg-[#0f0f11] border-white/5 hover:border-white/10'
            }`}
          >
            <game.icon className={`w-6 h-6 ${activeGame === game.id ? 'text-[#c5a059]' : 'text-slate-500'}`} />
            <span className={`text-[10px] font-black uppercase tracking-widest ${activeGame === game.id ? 'text-[#c5a059]' : 'text-slate-500'}`}>{game.label}</span>
            <span className="text-[9px] text-slate-600 font-serif italic">{game.desc}</span>
          </button>
        ))}
      </div>

      {/* Active Game */}
      <div className="bg-[#0f0f11] rounded-[3.5rem] p-10 lg:p-14 border border-white/5 shadow-2xl relative overflow-hidden">
        <div className="absolute top-0 left-0 w-80 h-80 bg-[#c5a059]/5 rounded-full blur-[100px] -ml-40 -mt-40 pointer-events-none" />
        <div className="relative z-10">
          {activeGame === 'match' && <MatchGame flashcards={gameCards} />}
          {activeGame === 'speed' && <SpeedRecall flashcards={gameCards} />}
          {activeGame === 'type' && <TypeChallenge flashcards={gameCards} />}
          {activeGame === 'survival' && <SurvivalMode flashcards={gameCards} />}
        </div>
      </div>

      {/* Data Source & Feedback Info */}
      <div className="flex items-center justify-between px-4">
        <div className="flex items-center gap-3 text-slate-600">
          <div className={`w-2 h-2 rounded-full ${flashcards && flashcards.length > 0 ? 'bg-[#8da290] shadow-[0_0_8px_#8da290]' : 'bg-[#c5a059] shadow-[0_0_8px_#c5a059]'}`} />
          <span className="text-[10px] font-black uppercase tracking-widest">
            {flashcards && flashcards.length > 0 ? 'Live Data Active' : 'Demo Mode — Upload content for personalized games'}
          </span>
        </div>
        <div className="flex items-center gap-2 text-slate-600">
          <Shield className="w-3 h-3" />
          <span className="text-[10px] font-black uppercase tracking-widest">Scores affect revision schedule</span>
        </div>
      </div>
    </div>
  );
};

export { syncQueue };
export default SynapticMatchGame;
