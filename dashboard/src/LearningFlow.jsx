import React, { useState, useEffect, useRef } from 'react';
import { Volume2, Brain, CheckCircle2, X as CloseIcon, Zap, RotateCcw, Trophy, Keyboard } from 'lucide-react';

const API_BASE = "http://127.0.0.1:8000";

/**
 * LearningFlow - Full guided learning session per card
 * Flow: Audio Overview → Random Quiz Game → Result
 */
const LearningFlow = ({ flashcard, onClose }) => {
  const [stage, setStage] = useState('audio'); // 'audio' | 'quiz' | 'type' | 'result'
  const [audioPlaying, setAudioPlaying] = useState(false);
  const [quizAnswer, setQuizAnswer] = useState('');
  const [quizResult, setQuizResult] = useState(null); // 'correct' | 'wrong'
  const [showAnswer, setShowAnswer] = useState(false);
  const [gameType, setGameType] = useState(null);
  const audioRef = useRef(null);

  // Pick a random game after audio
  useEffect(() => {
    const games = ['quiz', 'type'];
    setGameType(games[Math.floor(Math.random() * games.length)]);
  }, []);

  // Start audio automatically
  useEffect(() => {
    startAudio();
  }, []);

  const startAudio = () => {
    setAudioPlaying(true);
    const text = `${flashcard.topic_name}. ${flashcard.summary || flashcard.answer || flashcard.question}`;
    
    // Try backend audio first
    const audio = new Audio(`${API_BASE}/audio/${flashcard.id}`);
    audioRef.current = audio;
    
    audio.onended = () => {
      setAudioPlaying(false);
      // Auto-advance to quiz after audio
      setTimeout(() => setStage(gameType || 'quiz'), 1000);
    };
    
    audio.onerror = () => {
      // Fallback to browser TTS
      const utter = new SpeechSynthesisUtterance(text);
      utter.rate = 0.85;
      utter.onend = () => {
        setAudioPlaying(false);
        setTimeout(() => setStage(gameType || 'quiz'), 1000);
      };
      window.speechSynthesis.speak(utter);
    };
    
    audio.play().catch(() => {
      const utter = new SpeechSynthesisUtterance(text);
      utter.rate = 0.85;
      utter.onend = () => {
        setAudioPlaying(false);
        setTimeout(() => setStage(gameType || 'quiz'), 1000);
      };
      window.speechSynthesis.speak(utter);
    });
  };

  const skipAudio = () => {
    if (audioRef.current) audioRef.current.pause();
    window.speechSynthesis.cancel();
    setAudioPlaying(false);
    setStage(gameType || 'quiz');
  };

  const handleQuizResult = (result) => {
    setQuizResult(result);
    setStage('result');
    // Send review to backend
    fetch(`${API_BASE}/flashcard/review`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ flashcard_id: flashcard.id, result })
    }).catch(() => {});
  };

  const handleTypeSubmit = () => {
    const similarity = calculateSimilarity(quizAnswer, flashcard.answer);
    const result = similarity >= 40 ? 'remembered' : 'forgot';
    setQuizResult(result);
    setShowAnswer(true);
    setTimeout(() => setStage('result'), 2000);
    fetch(`${API_BASE}/flashcard/review`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ flashcard_id: flashcard.id, result })
    }).catch(() => {});
  };

  const calculateSimilarity = (input, answer) => {
    const aWords = new Set(input.toLowerCase().trim().split(/\s+/));
    const bWords = new Set(answer.toLowerCase().trim().split(/\s+/));
    let matches = 0;
    for (const word of aWords) { if (bWords.has(word)) matches++; }
    return Math.round((matches / Math.max(bWords.size, 1)) * 100);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-md" onClick={onClose}>
      <div className="bg-[#0f0f11] rounded-[3rem] border border-white/10 p-10 w-full max-w-2xl shadow-2xl relative" onClick={(e) => e.stopPropagation()}>
        
        {/* Close button */}
        <button onClick={onClose} className="absolute top-6 right-6 p-2 bg-white/5 rounded-xl hover:bg-white/10">
          <CloseIcon className="w-5 h-5 text-slate-400" />
        </button>

        {/* Header - always visible */}
        <div className="mb-8">
          <span className="text-[10px] font-black text-[#c5a059] uppercase tracking-[0.3em]">{flashcard.topic_name}</span>
          <h3 className="text-2xl font-black text-[#f4f1ea] font-serif mt-2 leading-tight">{flashcard.question}</h3>
        </div>

        {/* Stage: Audio */}
        {stage === 'audio' && (
          <div className="flex flex-col items-center py-12 text-center">
            <div className={`w-24 h-24 rounded-full flex items-center justify-center mb-8 border-2 ${audioPlaying ? 'bg-[#c5a059]/20 border-[#c5a059] animate-pulse' : 'bg-white/5 border-white/10'}`}>
              <Volume2 className={`w-10 h-10 ${audioPlaying ? 'text-[#c5a059]' : 'text-slate-500'}`} />
            </div>
            <p className="text-[#8da290] font-serif italic text-lg mb-2">
              {audioPlaying ? 'Listening to audio overview...' : 'Preparing audio...'}
            </p>
            <p className="text-slate-500 text-sm mb-8">A quiz will start automatically after the audio</p>
            {audioPlaying && (
              <button onClick={skipAudio} className="px-6 py-3 bg-white/5 border border-white/10 rounded-2xl text-slate-400 text-xs font-black uppercase tracking-widest hover:bg-white/10 transition-all">
                Skip to Quiz →
              </button>
            )}
          </div>
        )}

        {/* Stage: Quiz (Recall) */}
        {stage === 'quiz' && (
          <div className="flex flex-col items-center py-8 text-center">
            <div className="w-16 h-16 bg-[#c5a059]/10 rounded-full flex items-center justify-center mb-6 border border-[#c5a059]/20">
              <Brain className="w-8 h-8 text-[#c5a059]" />
            </div>
            <p className="text-[#f4f1ea] font-serif text-lg mb-2">Do you remember the answer?</p>
            <p className="text-slate-500 text-sm mb-8">Rate your recall honestly</p>
            
            {!showAnswer ? (
              <button onClick={() => setShowAnswer(true)} className="px-10 py-4 bg-[#c5a059] text-black font-black uppercase text-xs tracking-widest rounded-full hover:bg-white transition-all">
                Reveal Answer
              </button>
            ) : (
              <div className="w-full space-y-6">
                <div className="p-6 bg-[#8da290]/10 rounded-2xl border border-[#8da290]/20">
                  <p className="text-[#8da290] font-serif italic">{flashcard.answer}</p>
                </div>
                <div className="flex items-center justify-center gap-4">
                  <button onClick={() => handleQuizResult('remembered')} className="px-8 py-4 bg-[#8da290] text-black font-black uppercase text-xs tracking-widest rounded-full hover:scale-105 transition-all">
                    <CheckCircle2 className="w-4 h-4 inline mr-2" /> Got It
                  </button>
                  <button onClick={() => handleQuizResult('forgot')} className="px-8 py-4 bg-rose-500/20 text-rose-400 font-black uppercase text-xs tracking-widest rounded-full border border-rose-500/30 hover:scale-105 transition-all">
                    <Zap className="w-4 h-4 inline mr-2" /> Forgot
                  </button>
                </div>
              </div>
            )}
          </div>
        )}

        {/* Stage: Type Challenge */}
        {stage === 'type' && (
          <div className="flex flex-col items-center py-8">
            <div className="w-16 h-16 bg-[#c5a059]/10 rounded-full flex items-center justify-center mb-6 border border-[#c5a059]/20">
              <Keyboard className="w-8 h-8 text-[#c5a059]" />
            </div>
            <p className="text-[#f4f1ea] font-serif text-lg mb-2 text-center">Type what you remember</p>
            <p className="text-slate-500 text-sm mb-6 text-center">40%+ keyword match = pass</p>
            
            {showAnswer ? (
              <div className="w-full p-6 bg-[#8da290]/10 rounded-2xl border border-[#8da290]/20">
                <p className="text-[#8da290] font-serif italic">{flashcard.answer}</p>
                <p className="text-xs text-slate-500 mt-3">Similarity: {calculateSimilarity(quizAnswer, flashcard.answer)}%</p>
              </div>
            ) : (
              <div className="w-full space-y-4">
                <textarea
                  value={quizAnswer}
                  onChange={(e) => setQuizAnswer(e.target.value)}
                  placeholder="Type your answer..."
                  className="w-full h-28 bg-[#0a0a0b] border border-white/10 rounded-2xl p-5 text-[#f4f1ea] placeholder-slate-700 font-serif resize-none focus:border-[#c5a059]/30 outline-none"
                  autoFocus
                />
                <button onClick={handleTypeSubmit} disabled={!quizAnswer.trim()} className="w-full px-8 py-4 bg-[#c5a059] text-black font-black uppercase text-xs tracking-widest rounded-full hover:bg-white transition-all disabled:opacity-30">
                  Submit Answer
                </button>
              </div>
            )}
          </div>
        )}

        {/* Stage: Result */}
        {stage === 'result' && (
          <div className="flex flex-col items-center py-12 text-center">
            <div className={`w-20 h-20 rounded-full flex items-center justify-center mb-6 border-2 ${quizResult === 'remembered' ? 'bg-[#8da290]/20 border-[#8da290]' : 'bg-rose-500/20 border-rose-500'}`}>
              {quizResult === 'remembered' ? <Trophy className="w-10 h-10 text-[#8da290]" /> : <RotateCcw className="w-10 h-10 text-rose-400" />}
            </div>
            <h4 className="text-3xl font-black text-[#f4f1ea] font-serif mb-2">
              {quizResult === 'remembered' ? 'Well Done!' : 'Keep Practicing'}
            </h4>
            <p className="text-slate-500 text-sm mb-8">
              {quizResult === 'remembered' ? 'Stability boosted — next review pushed further out.' : 'Stability reset — you\'ll see this card again sooner.'}
            </p>
            <button onClick={onClose} className="px-10 py-4 bg-[#c5a059] text-black font-black uppercase text-xs tracking-widest rounded-full hover:bg-white transition-all">
              Done
            </button>
          </div>
        )}

        {/* Progress dots */}
        <div className="flex items-center justify-center gap-3 mt-8">
          <div className={`w-2 h-2 rounded-full ${stage === 'audio' ? 'bg-[#c5a059]' : 'bg-white/20'}`} />
          <div className={`w-2 h-2 rounded-full ${stage === 'quiz' || stage === 'type' ? 'bg-[#c5a059]' : 'bg-white/20'}`} />
          <div className={`w-2 h-2 rounded-full ${stage === 'result' ? 'bg-[#c5a059]' : 'bg-white/20'}`} />
        </div>
      </div>
    </div>
  );
};

export default LearningFlow;
