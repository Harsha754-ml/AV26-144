import React, { useState, useEffect } from 'react';

const SplashScreen = ({ onComplete }) => {
  const [progress, setProgress] = useState(0);
  const [phase, setPhase] = useState(0); // 0=logo, 1=text, 2=loading, 3=done

  useEffect(() => {
    // Phase transitions
    setTimeout(() => setPhase(1), 400);
    setTimeout(() => setPhase(2), 1200);
    
    // Progress bar
    const interval = setInterval(() => {
      setProgress(prev => {
        if (prev >= 100) {
          clearInterval(interval);
          setTimeout(() => setPhase(3), 200);
          setTimeout(() => onComplete(), 600);
          return 100;
        }
        return prev + Math.random() * 15 + 5;
      });
    }, 150);

    return () => clearInterval(interval);
  }, [onComplete]);

  return (
    <div className="fixed inset-0 z-[100] bg-[#0a0a0b] flex items-center justify-center overflow-hidden">
      {/* Background neural particles */}
      <div className="absolute inset-0">
        {[...Array(20)].map((_, i) => (
          <div
            key={i}
            className="absolute w-1 h-1 bg-[#c5a059]/30 rounded-full animate-pulse"
            style={{
              left: `${Math.random() * 100}%`,
              top: `${Math.random() * 100}%`,
              animationDelay: `${Math.random() * 2}s`,
              animationDuration: `${2 + Math.random() * 3}s`,
            }}
          />
        ))}
      </div>

      {/* Radial glow */}
      <div className="absolute w-[600px] h-[600px] bg-[#c5a059]/[0.03] rounded-full blur-[150px] animate-pulse" />

      {/* Main content */}
      <div className={`relative flex flex-col items-center transition-all duration-700 ${phase >= 3 ? 'opacity-0 scale-95' : 'opacity-100'}`}>
        
        {/* Logo */}
        <div className={`transition-all duration-700 ${phase >= 0 ? 'opacity-100 scale-100' : 'opacity-0 scale-50'}`}>
          <div className="w-24 h-24 bg-[#c5a059] rounded-3xl shadow-[0_0_60px_rgba(197,160,89,0.4)] flex items-center justify-center mb-8 relative">
            {/* Neural icon */}
            <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="black" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M12 2a4 4 0 0 1 4 4c0 1.5-.8 2.8-2 3.4V12h3a3 3 0 0 1 3 3v1a2 2 0 0 1-2 2h-1" />
              <path d="M12 2a4 4 0 0 0-4 4c0 1.5.8 2.8 2 3.4V12H7a3 3 0 0 0-3 3v1a2 2 0 0 0 2 2h1" />
              <circle cx="12" cy="18" r="4" />
              <circle cx="12" cy="6" r="1" fill="black" />
            </svg>
            {/* Pulse ring */}
            <div className="absolute inset-0 rounded-3xl border-2 border-[#c5a059] animate-ping opacity-20" />
          </div>
        </div>

        {/* Title */}
        <div className={`text-center transition-all duration-700 delay-200 ${phase >= 1 ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4'}`}>
          <h1 className="text-5xl font-black text-[#c5a059] font-serif tracking-tight mb-2">MemoryForge</h1>
          <p className="text-[11px] font-black tracking-[0.4em] text-[#8da290] uppercase">Cognitive Operating System v2</p>
        </div>

        {/* Loading bar */}
        <div className={`mt-12 w-80 transition-all duration-500 ${phase >= 2 ? 'opacity-100' : 'opacity-0'}`}>
          <div className="w-full h-1 bg-white/5 rounded-full overflow-hidden">
            <div 
              className="h-full bg-gradient-to-r from-[#c5a059] to-[#8da290] rounded-full transition-all duration-300"
              style={{ width: `${Math.min(progress, 100)}%` }}
            />
          </div>
          <div className="flex justify-between mt-4">
            <span className="text-[9px] font-black text-slate-600 uppercase tracking-widest">
              {progress < 30 ? 'Initializing HLR Engine...' : 
               progress < 60 ? 'Loading Neural Graph...' : 
               progress < 85 ? 'Calibrating Retention Model...' : 
               'System Ready'}
            </span>
            <span className="text-[9px] font-mono text-[#c5a059]">{Math.min(Math.round(progress), 100)}%</span>
          </div>
        </div>

        {/* Tech badges */}
        <div className={`mt-10 flex items-center gap-4 transition-all duration-500 delay-300 ${phase >= 2 ? 'opacity-100' : 'opacity-0'}`}>
          {['PyTorch', 'Gemini AI', 'CrewAI', 'WebSocket'].map((tech, i) => (
            <span key={i} className="text-[8px] font-black text-slate-700 uppercase tracking-widest px-3 py-1.5 bg-white/[0.02] rounded-lg border border-white/5">
              {tech}
            </span>
          ))}
        </div>
      </div>
    </div>
  );
};

export default SplashScreen;
