import React, { useState, useEffect, useRef, useMemo } from 'react';
import { AreaChart, Area, LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid, ReferenceLine, Scatter } from 'recharts';
import { Activity, Brain, Layers, ShieldCheck, Zap, AlertTriangle, Upload, Globe, Type, Send, Clock, Sparkles, User, Database, Play, Square, FileText, Youtube, RefreshCw, X as CloseIcon, PlusCircle } from 'lucide-react';

const API_BASE = "http://127.0.0.1:8000";
const WS_URL = "ws://127.0.0.1:8000/ws";

// HUMANLY HELPER COMPONENTS
const StatusCard = ({ label, value, icon, sub, urgency }) => (
  <div className={`bg-[#0f0f11] rounded-[2.5rem] p-8 border border-white/5 relative group hover:border-[#c5a059]/20 transition-all shadow-xl overflow-hidden`}>
     {urgency === 'critical' && <div className="absolute top-0 right-0 w-24 h-24 bg-rose-500/5 rounded-full blur-[40px] -mr-12 -mt-12" />}
     <div className="flex justify-between items-start mb-6">
        <div className="p-4 bg-white/[0.03] rounded-2xl group-hover:scale-110 transition-transform">
           {icon}
        </div>
        <span className="text-[9px] font-black text-slate-600 uppercase tracking-widest leading-none mt-2">{label}</span>
     </div>
     <div className="space-y-1">
        <p className={`text-4xl font-black tracking-tighter ${urgency === 'critical' ? 'text-rose-400' : 'text-[#f4f1ea]'}`}>{value}</p>
        <p className="text-[10px] font-serif italic text-slate-500">{sub}</p>
     </div>
  </div>
);

// MOCK DATA FOR DEMO MODE
const MOCK_FLASHCARDS = [
  { 
    id: "m1", topic_name: "Philosophy: Stocism", urgency_level: "safe", retention_score: 94, stability: 120, next_reminder_minutes: 480,
    question: "What is the 'Dichotomy of Control' as defined by Epictetus?", source_type: "text",
    curve_points: Array.from({length: 10}, (_, i) => ({ day: i, score: 90 + Math.random() * 10 }))
  },
  { 
    id: "m2", topic_name: "Quantum Mechanics", urgency_level: "critical", retention_score: 38, stability: 12, next_reminder_minutes: 15,
    question: "Define the Heisenberg Uncertainty Principle in terms of position and momentum.", source_type: "youtube",
    curve_points: Array.from({length: 10}, (_, i) => ({ day: i, score: 80 - (i * 12) }))
  },
  { 
    id: "m3", topic_name: "React: Performance", urgency_level: "warning", retention_score: 72, stability: 45, next_reminder_minutes: 120,
    question: "When should useMemo be favored over simple memoization?", source_type: "manual",
    curve_points: Array.from({length: 10}, (_, i) => ({ day: i, score: 95 - (i * 5) }))
  }
];

const MOCK_TREND = [
  { day: 'Mon', load: 45, retention: 82 },
  { day: 'Tue', load: 52, retention: 85 },
  { day: 'Wed', load: 68, retention: 79 },
  { day: 'Thu', load: 75, retention: 74 },
  { day: 'Fri', load: 88, retention: 81 },
  { day: 'Sat', load: 92, retention: 88 },
  { day: 'Sun', load: 95, retention: 91 },
];

function App() {
  const [data, setData] = useState({
    flashcards: [],
    events: [],
    dashboard: { total_cards: 0, critical_cards: 0, warning_cards: 0, active_plans: 0, demo_mode: false }
  });
  const [isConnected, setIsConnected] = useState(false);
  const [simulationMode, setSimulationMode] = useState(false);
  
  // Audio state
  const [playingAudioId, setPlayingAudioId] = useState(null);
  const audioRef = useRef(null);
  
  // Selection
  const [selectedCardId, setSelectedCardId] = useState(null);

  // Modals
  const [showIngestModal, setShowIngestModal] = useState(false);
  
  // Ingest form state
  const [ingestTab, setIngestTab] = useState('text');
  const [topicName, setTopicName] = useState('');
  const [textContent, setTextContent] = useState('');
  const [youtubeUrl, setYoutubeUrl] = useState('');
  const [manualQ, setManualQ] = useState('');
  const [manualA, setManualA] = useState('');
  const fileInputRef = useRef(null);
  const [ingestLoading, setIngestLoading] = useState(false);

  // Auto-scroll event log
  const eventLogRef = useRef(null);

  useEffect(() => {
    let ws;
    const connect = () => {
      ws = new WebSocket(WS_URL);
      ws.onopen = () => setIsConnected(true);
      ws.onmessage = (event) => {
        try {
          const parsed = JSON.parse(event.data);
          setData(parsed);
          setSimulationMode(parsed.flashcards.length === 0);
          if (eventLogRef.current) {
             eventLogRef.current.scrollTop = eventLogRef.current.scrollHeight;
          }
        } catch(e) {}
      };
      ws.onclose = () => {
        setIsConnected(false);
        setSimulationMode(true);
        setTimeout(connect, 3000);
      };
    };
    connect();
    return () => { if (ws) ws.close(); };
  }, []);

  const toggleDemoMode = async () => {
    try {
      await fetch(`${API_BASE}/settings/demo-mode`, {
         method: 'POST',
         headers: { 'Content-Type': 'application/json' },
         body: JSON.stringify({ enabled: !data.dashboard.demo_mode })
      });
    } catch (e) {
      console.error(e);
    }
  };

  const handleReview = async (fcId, result) => {
     try {
       await fetch(`${API_BASE}/flashcard/review`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ flashcard_id: fcId, result })
       });
     } catch (e) { console.error(e); }
  };

  const toggleAudio = (fcId) => {
    if (playingAudioId === fcId) {
       audioRef.current?.pause();
       setPlayingAudioId(null);
    } else {
       if (audioRef.current) audioRef.current.pause();
       const audioUrl = simulationMode 
           ? 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'
           : `${API_BASE}/audio/${fcId}`;
           
       const newAudio = new Audio(audioUrl);
       newAudio.onended = () => setPlayingAudioId(null);
       newAudio.play().catch(e => {
           console.error("Audio failed", e);
           setPlayingAudioId(null);
       });
       audioRef.current = newAudio;
       setPlayingAudioId(fcId);
    }
  };

  const activeCards = useMemo(() => {
    return simulationMode || data.flashcards.length === 0 ? MOCK_FLASHCARDS : data.flashcards;
  }, [simulationMode, data.flashcards]);

  const activeEvents = useMemo(() => {
    if (data.events.length > 0) return data.events;
    return [
      { text: "System initialized", timestamp: Date.now()/1000 - 3600 }
    ];
  }, [data.events]);

  const selectedCard = useMemo(() => {
     if (!selectedCardId) return activeCards[0] || null;
     return activeCards.find(c => c.id === selectedCardId) || activeCards[0] || null;
  }, [selectedCardId, activeCards]);

  const handleIngest = async (e) => {
    e.preventDefault();
    if (!topicName.trim()) return alert("Topic Name required.");
    setIngestLoading(true);

    try {
      let endpoint = '';
      let body;
      let headers = {};

      if (ingestTab === 'manual') {
         endpoint = '/flashcard/add';
         headers = { 'Content-Type': 'application/json' };
         body = JSON.stringify({ topic_name: topicName, question: manualQ, answer: manualA, source_type: 'manual' });
      } else if (ingestTab === 'file') {
         endpoint = '/ingest/file';
         body = new FormData();
         body.append('topic_name', topicName);
         body.append('file', fileInputRef.current.files[0]);
      } else {
         endpoint = ingestTab === 'text' ? '/ingest/text' : '/ingest/youtube';
         headers = { 'Content-Type': 'application/json' };
         body = JSON.stringify({ 
           topic_name: topicName, 
           [ingestTab === 'text' ? 'text' : 'url']: ingestTab === 'text' ? textContent : youtubeUrl 
         });
      }

      const res = await fetch(`${API_BASE}${endpoint}`, { method: 'POST', headers, body });
      if (res.ok) {
         setShowIngestModal(false);
         setTopicName(''); setTextContent(''); setYoutubeUrl(''); setManualQ(''); setManualA('');
      } else {
         alert("Ingest failed.");
      }
    } catch (err) {
      alert("Connection error.");
    } finally {
      setIngestLoading(false);
    }
  };

  return (
    <div className="flex h-screen w-screen bg-[#0a0a0b] text-[#f4f1ea] font-sans overflow-hidden">
      
      {/* SIDEBAR */}
      <aside className="w-80 h-full flex flex-col bg-[#0f0f11] border-r border-white/5 z-20 shrink-0">
        <div className="p-8 pb-4">
           <div className="flex items-center gap-4 mb-8">
              <div className="w-11 h-11 bg-[#c5a059] rounded-xl flex items-center justify-center border border-white/5">
                 <Brain className="w-6 h-6 text-black" />
              </div>
              <div>
                 <h1 className="text-2xl font-bold font-serif text-[#c5a059]">MemoryForge</h1>
                 <p className="text-[10px] font-black tracking-[0.3em] text-[#8da290] uppercase">v2</p>
              </div>
           </div>

           <div className={`p-5 rounded-[2rem] border transition-all ${isConnected ? 'bg-[#8da290]/5 border-[#8da290]/20' : 'bg-rose-500/5 border-rose-500/20'}`}>
              <div className="flex items-center justify-between mb-2">
                 <span className="text-[9px] font-black uppercase tracking-widest text-slate-500">Synaptic Relay</span>
                 <div className={`w-2 h-2 rounded-full ${isConnected ? 'bg-[#8da290]' : 'bg-rose-500 animate-pulse'}`} />
              </div>
              <p className={`text-xs font-serif italic tracking-wide ${isConnected ? 'text-[#8da290]' : 'text-rose-400'}`}>
                 {isConnected ? 'Connected' : 'Disconnected'}
              </p>
           </div>
        </div>

        <button 
           onClick={() => setShowIngestModal(true)}
           className="mx-8 mb-6 bg-[#c5a059]/10 text-[#c5a059] border border-[#c5a059]/30 rounded-2xl py-4 font-black text-xs tracking-widest uppercase hover:bg-[#c5a059]/20 transition-all flex items-center justify-center gap-2"
        >
           <PlusCircle className="w-4 h-4" /> Add Flashcard
        </button>
        
        <div className="px-8 flex items-center gap-2 mb-4 group cursor-default">
           <Activity className="w-3 h-3 text-[#c5a059]" />
           <h3 className="text-[10px] font-black uppercase tracking-widest text-slate-500">Synaptic Activity</h3>
        </div>
        
        <div ref={eventLogRef} className="flex-1 overflow-y-auto px-8 py-2 space-y-8 custom-scrollbar mb-8 scroll-smooth">
           {activeEvents.map((evt, i) => (
             <div key={i} className="relative pl-6">
                <div className="absolute left-0 top-1.5 w-1 h-1 bg-[#c5a059]/50 rounded-full" />
                <div className="absolute left-[1.5px] top-4 bottom-[-2.5rem] w-[1px] bg-white/5" />
                <p className="text-xs font-medium text-slate-400 leading-relaxed">{evt.text}</p>
                <time className="text-[9px] font-mono text-slate-600 uppercase mt-1 block">
                   {new Date(evt.timestamp * 1000).toLocaleTimeString()}
                </time>
             </div>
           ))}
        </div>

        <div className="p-8 bg-[#0a0c10] border-t border-white/5 flex justify-between items-center">
           <div className="flex items-center gap-3 text-slate-600 opacity-50">
              <User className="w-4 h-4" />
              <span className="text-[10px] font-black tracking-widest uppercase">Harsha</span>
           </div>
           <button onClick={toggleDemoMode} className={`text-[10px] px-3 py-1 rounded-full border ${data.dashboard.demo_mode ? 'bg-[#c5a059] text-black' : 'bg-transparent text-slate-500 border-white/10'}`}>
              Demo
           </button>
        </div>
      </aside>

      {/* MAIN VIEWPORT */}
      <main className="flex-1 h-full flex flex-col relative custom-scrollbar">
         {/* TOP BAR / STATS */}
         <div className="p-10 shrink-0 border-b border-white/5">
            <header className="flex items-end justify-between gap-10">
               <div>
                  <h2 className="text-5xl font-black text-[#f4f1ea] font-serif tracking-tighter">Mission Control</h2>
                  <p className="text-[#8da290] font-serif italic mt-2">Active learning environment.</p>
               </div>
               
               <div className="flex gap-6">
                  <StatusCard label="Total Cards" value={data.dashboard?.total_cards || activeCards.length} icon={<Layers className="text-[#c5a059]" />} />
                  <StatusCard label="Critical" value={data.dashboard?.critical_cards || activeCards.filter(c => c.urgency_level==='critical').length} icon={<AlertTriangle className="text-rose-400" />} urgency="critical" />
               </div>
            </header>
         </div>

         {/* SPLIT LAYOUT */}
         <div className="flex-1 flex overflow-hidden">
            {/* CARDS GRID (SCROLLABLE) */}
            <div className="flex-1 p-10 overflow-y-auto custom-scrollbar">
               <div className="grid grid-cols-1 xl:grid-cols-2 2xl:grid-cols-3 gap-8">
                  {activeCards.map((fc) => {
                     // Shake animation on critical
                     const isCritical = fc.retention_score < 30;
                     const isForgotten = fc.retention_score === 0;
                     
                     return (
                     <div 
                        key={fc.id} 
                        onClick={() => setSelectedCardId(fc.id)}
                        className={`relative bg-[#0f0f11] rounded-[3rem] p-8 border cursor-pointer transition-all ${selectedCardId === fc.id ? 'border-[#c5a059]' : 'border-white/5'} ${isCritical ? 'animate-[shake_0.5s_infinite]' : ''}`}
                     >
                        {isForgotten && (
                           <div className="absolute inset-0 bg-black/80 rounded-[3rem] z-20 flex items-center justify-center backdrop-blur-sm">
                              <span className="text-rose-500 font-black text-2xl tracking-widest uppercase rotate-[-15deg] border-4 border-rose-500 p-4 rounded-xl">Forgotten</span>
                           </div>
                        )}
                        <div className="flex justify-between items-start mb-6">
                           <h3 className="text-xl font-black text-[#f4f1ea] font-serif line-clamp-1">{fc.topic_name}</h3>
                           <div className={`px-3 py-1 rounded-xl text-[9px] font-black uppercase tracking-widest border ${
                              fc.urgency_level === 'critical' ? 'bg-rose-500/10 text-rose-500 border-rose-500/20' :
                              fc.urgency_level === 'warning' ? 'bg-orange-500/10 text-orange-400 border-orange-500/20' :
                              'bg-[#8da290]/10 text-[#8da290] border-[#8da290]/20'
                           }`}>
                              {fc.urgency_level}
                           </div>
                        </div>
                        
                        <div className="mb-4">
                           <span className="text-xs text-slate-500 flex items-center gap-2">
                              {fc.source_type === 'youtube' ? <Youtube className="w-3 h-3"/> : fc.source_type === 'pdf' ? <FileText className="w-3 h-3"/> : <Type className="w-3 h-3"/>}
                              {fc.source_type || 'manual'}
                           </span>
                        </div>

                        <p className="text-slate-400 text-sm italic mb-6 line-clamp-3 min-h-[60px]">"{fc.question}"</p>
                        
                        {/* Animated Progress bar */}
                        <div className="h-2 w-full bg-white/5 rounded-full mb-6 overflow-hidden">
                           <div 
                              className={`h-full rounded-full transition-all duration-1000 ${fc.retention_score > 50 ? 'bg-[#8da290]' : 'bg-rose-500'}`}
                              style={{ width: `${fc.retention_score}%` }}
                           />
                        </div>

                        <div className="flex justify-between items-center">
                           <div className="flex flex-col">
                              <span className="text-[10px] uppercase text-slate-600 mb-1">R = e^(-t/S)</span>
                              <span className={`text-2xl font-black ${fc.retention_score < 50 ? 'text-rose-500' : 'text-[#8da290]'}`}>
                                 {Math.round(fc.retention_score)}%
                              </span>
                           </div>
                           
                           {/* Review Buttons */}
                           <div className="flex gap-2 relative z-30">
                              <button onClick={(e) => { e.stopPropagation(); handleReview(fc.id, 'forgot'); }} className="px-3 py-1 bg-rose-500/10 text-rose-400 rounded hover:bg-rose-500/20 text-xs font-bold">Forgot</button>
                              <button onClick={(e) => { e.stopPropagation(); handleReview(fc.id, 'hard'); }} className="px-3 py-1 bg-orange-500/10 text-orange-400 rounded hover:bg-orange-500/20 text-xs font-bold">Hard</button>
                              <button onClick={(e) => { e.stopPropagation(); handleReview(fc.id, 'remembered'); }} className="px-3 py-1 bg-[#8da290]/10 text-[#8da290] rounded hover:bg-[#8da290]/20 text-xs font-bold">Rem</button>
                           </div>
                        </div>
                     </div>
                  )})}
               </div>
            </div>

            {/* BOTTOM/RIGHT GRAPH PANEL */}
            {selectedCard && (
               <div className="w-[450px] shrink-0 border-l border-white/5 bg-[#0a0c10] p-8 flex flex-col">
                  <h3 className="text-2xl font-serif text-[#c5a059] mb-2">{selectedCard.topic_name} Curve</h3>
                  <div className="text-xs text-slate-500 mb-8 font-mono">
                     Formula: R = e^(-{selectedCard.next_reminder_minutes || 0} / {Math.round(selectedCard.stability)})
                  </div>
                  
                  <div className="h-64 w-full mb-8">
                     <ResponsiveContainer width="100%" height="100%">
                        <LineChart data={selectedCard.curve_points || []}>
                           <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" vertical={false} />
                           <XAxis dataKey="day" hide />
                           <YAxis domain={[0, 100]} hide />
                           <ReferenceLine y={50} stroke="rgba(244,63,94,0.5)" strokeDasharray="3 3" />
                           <Tooltip contentStyle={{backgroundColor: '#0f0f11', border:'none', color: '#fff'}} />
                           <Line type="monotone" dataKey="score" stroke="#c5a059" strokeWidth={3} dot={{r:4, fill:'#0a0a0b', stroke:'#c5a059', strokeWidth:2}} />
                        </LineChart>
                     </ResponsiveContainer>
                  </div>
                  
                  <div className="flex-1 bg-[#0f0f11] rounded-3xl p-6 border border-white/5">
                     <h4 className="text-xs uppercase tracking-widest text-slate-500 mb-4 font-black">Controls</h4>
                     <button 
                        onClick={() => toggleAudio(selectedCard.id)}
                        className={`w-full flex items-center justify-center gap-2 py-4 rounded-2xl font-bold transition-all ${playingAudioId === selectedCard.id ? 'bg-rose-500/20 text-rose-500' : 'bg-[#8da290]/10 text-[#8da290] hover:bg-[#8da290]/20'}`}
                     >
                        {playingAudioId === selectedCard.id ? <Square className="w-5 h-5"/> : <Play className="w-5 h-5" />}
                        {playingAudioId === selectedCard.id ? 'Stop Audio Overview' : 'Play Audio Overview'}
                     </button>
                  </div>
               </div>
            )}
         </div>
      </main>

      {/* INGEST MODAL */}
      {showIngestModal && (
         <div className="fixed inset-0 bg-black/80 z-50 flex items-center justify-center backdrop-blur-sm">
            <div className="bg-[#0f0f11] rounded-[3rem] w-[800px] border border-white/10 p-10 shadow-2xl relative">
               <button onClick={() => setShowIngestModal(false)} className="absolute top-8 right-8 text-slate-500 hover:text-white">
                  <CloseIcon className="w-6 h-6" />
               </button>
               
               <h2 className="text-3xl font-serif text-[#f4f1ea] mb-8">Add Flashcard</h2>
               
               <div className="flex gap-4 mb-8">
                  {['manual', 'text', 'youtube', 'file'].map(tab => (
                     <button key={tab} onClick={() => setIngestTab(tab)} className={`px-6 py-2 rounded-full text-xs font-bold uppercase ${ingestTab === tab ? 'bg-[#c5a059] text-black' : 'bg-white/5 text-slate-400 hover:bg-white/10'}`}>
                        {tab}
                     </button>
                  ))}
               </div>
               
               <form onSubmit={handleIngest} className="space-y-6">
                  <input required type="text" placeholder="Topic Name" value={topicName} onChange={e => setTopicName(e.target.value)} className="w-full bg-[#0a0a0b] border border-white/5 rounded-2xl px-6 py-4 text-white outline-none focus:border-[#c5a059]" />
                  
                  {ingestTab === 'manual' && (
                     <>
                        <input required type="text" placeholder="Question" value={manualQ} onChange={e => setManualQ(e.target.value)} className="w-full bg-[#0a0a0b] border border-white/5 rounded-2xl px-6 py-4 text-white outline-none focus:border-[#c5a059]" />
                        <textarea required placeholder="Answer" value={manualA} onChange={e => setManualA(e.target.value)} className="w-full h-32 bg-[#0a0a0b] border border-white/5 rounded-2xl px-6 py-4 text-white outline-none focus:border-[#c5a059]" />
                     </>
                  )}
                  {ingestTab === 'text' && (
                     <textarea required placeholder="Paste text here to let AI generate card..." value={textContent} onChange={e => setTextContent(e.target.value)} className="w-full h-40 bg-[#0a0a0b] border border-white/5 rounded-2xl px-6 py-4 text-white outline-none focus:border-[#c5a059]" />
                  )}
                  {ingestTab === 'youtube' && (
                     <input required type="url" placeholder="YouTube URL" value={youtubeUrl} onChange={e => setYoutubeUrl(e.target.value)} className="w-full bg-[#0a0a0b] border border-white/5 rounded-2xl px-6 py-4 text-white outline-none focus:border-[#c5a059]" />
                  )}
                  {ingestTab === 'file' && (
                     <div className="border-2 border-dashed border-white/10 rounded-2xl p-10 text-center">
                        <input required type="file" ref={fileInputRef} accept=".pdf,.txt" className="text-white" />
                     </div>
                  )}
                  
                  <button type="submit" disabled={ingestLoading} className="w-full py-4 bg-[#c5a059] text-black rounded-2xl font-black uppercase tracking-widest hover:bg-[#d8b577] flex justify-center items-center gap-2">
                     {ingestLoading ? <RefreshCw className="w-5 h-5 animate-spin" /> : 'Create'}
                  </button>
               </form>
            </div>
         </div>
      )}

      {/* Global styles for shake animation */}
      <style dangerouslySetInnerHTML={{__html: `
        @keyframes shake {
           0% { transform: translate(1px, 1px) rotate(0deg); }
           10% { transform: translate(-1px, -2px) rotate(-1deg); }
           20% { transform: translate(-3px, 0px) rotate(1deg); }
           30% { transform: translate(3px, 2px) rotate(0deg); }
           40% { transform: translate(1px, -1px) rotate(1deg); }
           50% { transform: translate(-1px, 2px) rotate(-1deg); }
           60% { transform: translate(-3px, 1px) rotate(0deg); }
           70% { transform: translate(3px, 1px) rotate(-1deg); }
           80% { transform: translate(-1px, -1px) rotate(1deg); }
           90% { transform: translate(1px, 2px) rotate(0deg); }
           100% { transform: translate(1px, -2px) rotate(-1deg); }
        }
      `}} />
    </div>
  );
}

export default App;
