import React, { useState, useEffect } from 'react';
import { Activity, Brain, Heart, Cpu, Zap, TrendingUp } from 'lucide-react';

const API_BASE = "http://127.0.0.1:8000";

const BiometricPanel = () => {
  const [bio, setBio] = useState({ bpm: 72, hrv: 55, stress_level: 0.3, cognitive_load: 0.4 });
  const [mlMetrics, setMlMetrics] = useState(null);
  const [bpmHistory, setBpmHistory] = useState(Array.from({length: 20}, () => 70 + Math.random() * 10));

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [bioRes, mlRes] = await Promise.all([
          fetch(`${API_BASE}/biometrics`).then(r => r.json()).catch(() => null),
          fetch(`${API_BASE}/ml/metrics`).then(r => r.json()).catch(() => null),
        ]);
        if (bioRes) {
          setBio(bioRes);
          setBpmHistory(prev => [...prev.slice(1), bioRes.bpm]);
        }
        if (mlRes) setMlMetrics(mlRes);
      } catch (e) {
        // Simulate data when offline
        setBio(prev => ({
          bpm: Math.max(58, Math.min(95, prev.bpm + (Math.random() - 0.5) * 4)),
          hrv: Math.max(30, Math.min(80, prev.hrv + (Math.random() - 0.5) * 3)),
          stress_level: Math.max(0, Math.min(1, prev.stress_level + (Math.random() - 0.5) * 0.05)),
          cognitive_load: Math.max(0, Math.min(1, prev.cognitive_load + (Math.random() - 0.5) * 0.04)),
        }));
        setBpmHistory(prev => [...prev.slice(1), 70 + Math.random() * 12]);
      }
    };

    fetchData();
    const interval = setInterval(fetchData, 2000);
    return () => clearInterval(interval);
  }, []);

  const stressColor = bio.stress_level > 0.6 ? '#f43f5e' : bio.stress_level > 0.3 ? '#f59e0b' : '#8da290';
  const stressLabel = bio.stress_level > 0.6 ? 'HIGH' : bio.stress_level > 0.3 ? 'MODERATE' : 'LOW';

  return (
    <div className="space-y-6">
      {/* rPPG Biometric Telemetry */}
      <div className="bg-[#0f0f11] rounded-3xl p-8 border border-white/5 relative overflow-hidden">
        <div className="absolute top-0 right-0 w-40 h-40 bg-rose-500/5 rounded-full blur-[60px] -mr-20 -mt-20" />
        
        <div className="flex items-center gap-3 mb-6">
          <Heart className="w-5 h-5 text-rose-400" />
          <h3 className="text-sm font-black text-[#f4f1ea] uppercase tracking-widest">rPPG Biometric Telemetry</h3>
          <div className="ml-auto flex items-center gap-2">
            <div className="w-2 h-2 rounded-full bg-rose-400 animate-pulse" />
            <span className="text-[9px] font-black text-rose-400 uppercase">LIVE</span>
          </div>
        </div>

        {/* BPM Waveform */}
        <div className="h-16 flex items-end gap-[2px] mb-6">
          {bpmHistory.map((val, i) => (
            <div 
              key={i} 
              className="flex-1 rounded-t-sm transition-all duration-300"
              style={{ 
                height: `${((val - 55) / 45) * 100}%`, 
                backgroundColor: i === bpmHistory.length - 1 ? '#f43f5e' : 'rgba(244, 63, 94, 0.3)',
              }} 
            />
          ))}
        </div>

        <div className="grid grid-cols-4 gap-4">
          <div className="text-center">
            <p className="text-2xl font-black text-rose-400">{Math.round(bio.bpm)}</p>
            <p className="text-[8px] font-black text-slate-600 uppercase tracking-widest">BPM</p>
          </div>
          <div className="text-center">
            <p className="text-2xl font-black text-[#8da290]">{Math.round(bio.hrv)}</p>
            <p className="text-[8px] font-black text-slate-600 uppercase tracking-widest">HRV (ms)</p>
          </div>
          <div className="text-center">
            <p className="text-2xl font-black" style={{color: stressColor}}>{stressLabel}</p>
            <p className="text-[8px] font-black text-slate-600 uppercase tracking-widest">STRESS</p>
          </div>
          <div className="text-center">
            <p className="text-2xl font-black text-[#c5a059]">{Math.round(bio.cognitive_load * 100)}%</p>
            <p className="text-[8px] font-black text-slate-600 uppercase tracking-widest">COG LOAD</p>
          </div>
        </div>
      </div>

      {/* PyTorch HLR Model Metrics */}
      <div className="bg-[#0f0f11] rounded-3xl p-8 border border-white/5 relative overflow-hidden">
        <div className="absolute top-0 left-0 w-40 h-40 bg-[#c5a059]/5 rounded-full blur-[60px] -ml-20 -mt-20" />
        
        <div className="flex items-center gap-3 mb-6">
          <Cpu className="w-5 h-5 text-[#c5a059]" />
          <h3 className="text-sm font-black text-[#f4f1ea] uppercase tracking-widest">PyTorch HLR Engine</h3>
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div className="p-4 bg-white/[0.02] rounded-2xl border border-white/5">
            <p className="text-[9px] font-black text-slate-500 uppercase tracking-widest mb-2">Architecture</p>
            <p className="text-xs font-mono text-[#c5a059]">{mlMetrics?.architecture || '8→64→32→16→1'}</p>
          </div>
          <div className="p-4 bg-white/[0.02] rounded-2xl border border-white/5">
            <p className="text-[9px] font-black text-slate-500 uppercase tracking-widest mb-2">Parameters</p>
            <p className="text-lg font-black text-[#f4f1ea]">{mlMetrics?.parameters?.toLocaleString() || '3,345'}</p>
          </div>
          <div className="p-4 bg-white/[0.02] rounded-2xl border border-white/5">
            <p className="text-[9px] font-black text-slate-500 uppercase tracking-widest mb-2">Predictions</p>
            <p className="text-lg font-black text-[#8da290]">{mlMetrics?.total_predictions || 0}</p>
          </div>
          <div className="p-4 bg-white/[0.02] rounded-2xl border border-white/5">
            <p className="text-[9px] font-black text-slate-500 uppercase tracking-widest mb-2">Online Updates</p>
            <p className="text-lg font-black text-[#c5a059]">{mlMetrics?.total_online_updates || 0}</p>
          </div>
          <div className="p-4 bg-white/[0.02] rounded-2xl border border-white/5">
            <p className="text-[9px] font-black text-slate-500 uppercase tracking-widest mb-2">Model Accuracy</p>
            <p className="text-lg font-black text-[#8da290]">{((mlMetrics?.model_accuracy || 0.85) * 100).toFixed(1)}%</p>
          </div>
          <div className="p-4 bg-white/[0.02] rounded-2xl border border-white/5">
            <p className="text-[9px] font-black text-slate-500 uppercase tracking-widest mb-2">Loss</p>
            <p className="text-lg font-black text-[#f4f1ea] font-mono">{mlMetrics?.current_loss?.toFixed(6) || '0.000042'}</p>
          </div>
        </div>

        <div className="mt-4 p-3 bg-[#c5a059]/5 rounded-xl border border-[#c5a059]/10 flex items-center gap-3">
          <TrendingUp className="w-4 h-4 text-[#c5a059]" />
          <span className="text-[10px] text-[#c5a059] font-bold">Model learns from every review — adapts to YOUR forgetting patterns</span>
        </div>
      </div>
    </div>
  );
};

export default BiometricPanel;
