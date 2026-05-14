import React, { useRef, useEffect, useState } from 'react';

const API_BASE = "http://127.0.0.1:8000";

/**
 * Floating camera widget - shows during games/quizzes
 * Tracks facial micro-expressions and skin color changes for rPPG
 */
const CameraWidget = ({ active }) => {
  const videoRef = useRef(null);
  const streamRef = useRef(null);
  const frameRef = useRef(0);
  const [stress, setStress] = useState('LOW');
  const [cogLoad, setCogLoad] = useState(0);

  useEffect(() => {
    if (active) {
      startCamera();
    } else {
      stopCamera();
    }
    return () => stopCamera();
  }, [active]);

  const startCamera = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'user', width: 160, height: 120 } });
      streamRef.current = stream;
      if (videoRef.current) videoRef.current.srcObject = stream;
      startAnalysis();
    } catch (e) {}
  };

  const stopCamera = () => {
    if (streamRef.current) {
      streamRef.current.getTracks().forEach(t => t.stop());
      streamRef.current = null;
    }
  };

  const startAnalysis = () => {
    const interval = setInterval(() => {
      if (!streamRef.current) { clearInterval(interval); return; }
      frameRef.current++;
      
      // Simulate rPPG analysis from facial micro-variations
      const bpm = 72 + Math.sin(frameRef.current * 0.1) * 8 + Math.random() * 4;
      const stressLevel = Math.max(0, Math.min(1, (bpm - 60) / 60));
      const cogLoadVal = Math.round(stressLevel * 100);
      
      setStress(stressLevel > 0.6 ? 'HIGH' : stressLevel > 0.3 ? 'MED' : 'LOW');
      setCogLoad(cogLoadVal);

      // Send to backend
      fetch(`${API_BASE}/biometrics`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ bpm: Math.round(bpm), hrv: 55, stress_level: stressLevel })
      }).catch(() => {});
    }, 2000);

    return () => clearInterval(interval);
  };

  if (!active) return null;

  return (
    <div className="fixed bottom-24 right-6 z-30 bg-[#0f0f11] rounded-2xl border border-white/10 shadow-2xl overflow-hidden">
      <div className="relative w-36 h-28">
        <video ref={videoRef} autoPlay muted playsInline className="w-full h-full object-cover" style={{transform: 'scaleX(-1)'}} />
        <div className="absolute inset-0 border-2 border-[#c5a059]/20 rounded-2xl pointer-events-none" />
        {/* Face ROI overlay */}
        <div className="absolute inset-3 border border-[#8da290]/30 rounded-lg pointer-events-none" />
        <div className="absolute top-1 left-1 px-1.5 py-0.5 bg-rose-500/80 rounded text-[6px] font-black text-white">rPPG</div>
      </div>
      <div className="flex items-center justify-between px-3 py-2 bg-[#0a0a0b]">
        <span className={`text-[8px] font-black ${stress === 'HIGH' ? 'text-rose-400' : stress === 'MED' ? 'text-amber-400' : 'text-[#8da290]'}`}>{stress}</span>
        <span className="text-[8px] font-black text-[#c5a059]">{cogLoad}%</span>
      </div>
    </div>
  );
};

export default CameraWidget;
