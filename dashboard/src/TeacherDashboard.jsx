import React, { useState, useEffect } from 'react';
import { AlertTriangle, Trophy, TrendingUp, Users, Brain, Award, Star, Target } from 'lucide-react';

const API_BASE = "http://127.0.0.1:8000";

// Demo student data (shows when real data isn't available)
const DEMO_STUDENTS = [
  { name: "Harsha K", username: "harsha", retention: 72, cards: 24, quizScore: 85, streak: 7, badges: ["Fast Learner", "7-Day Streak"], status: "active" },
  { name: "Arun A", username: "arun", retention: 45, cards: 18, quizScore: 62, streak: 3, badges: ["First Upload"], status: "struggling" },
  { name: "Priya S", username: "priya", retention: 88, cards: 32, quizScore: 94, streak: 14, badges: ["Master Recall", "14-Day Streak", "100 Cards"], status: "excellent" },
  { name: "Rahul M", username: "rahul", retention: 28, cards: 12, quizScore: 41, streak: 0, badges: [], status: "critical" },
  { name: "Sneha R", username: "sneha", retention: 65, cards: 20, quizScore: 78, streak: 5, badges: ["5-Day Streak"], status: "active" },
];

const TeacherDashboard = () => {
  const [students, setStudents] = useState(DEMO_STUDENTS);
  const [alerts, setAlerts] = useState([]);
  const [activeTab, setActiveTab] = useState('overview');

  useEffect(() => {
    // Fetch real data
    fetch(`${API_BASE}/teacher/alerts`).then(r => r.json()).then(setAlerts).catch(() => {});
    fetch(`${API_BASE}/teacher/students`).then(r => r.json()).then(data => {
      if (data && data.total_cards > 0) {
        // Merge real stats into first demo student
        setStudents(prev => prev.map((s, i) => i === 0 ? {...s, retention: Math.round(data.avg_retention), cards: data.total_cards} : s));
      }
    }).catch(() => {});
  }, []);

  const criticalStudents = students.filter(s => s.retention < 30);
  const avgRetention = Math.round(students.reduce((a, b) => a + b.retention, 0) / students.length);

  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <div className="flex items-center gap-3 text-[#c5a059] mb-4">
          <Users className="w-5 h-5" />
          <span className="text-[11px] font-black uppercase tracking-[0.3em]">Institution Dashboard</span>
        </div>
        <h2 className="text-5xl font-black text-[#f4f1ea] font-serif tracking-tighter">Teacher <span className="text-[#8da290] italic">Portal.</span></h2>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-4 gap-4">
        <div className="bg-[#0f0f11] rounded-2xl p-6 border border-white/5">
          <Users className="w-5 h-5 text-[#c5a059] mb-3" />
          <p className="text-3xl font-black text-[#f4f1ea]">{students.length}</p>
          <p className="text-[9px] font-black text-slate-500 uppercase tracking-widest mt-1">Students</p>
        </div>
        <div className="bg-[#0f0f11] rounded-2xl p-6 border border-white/5">
          <TrendingUp className="w-5 h-5 text-[#8da290] mb-3" />
          <p className="text-3xl font-black text-[#8da290]">{avgRetention}%</p>
          <p className="text-[9px] font-black text-slate-500 uppercase tracking-widest mt-1">Avg Retention</p>
        </div>
        <div className="bg-[#0f0f11] rounded-2xl p-6 border border-white/5">
          <AlertTriangle className="w-5 h-5 text-rose-400 mb-3" />
          <p className="text-3xl font-black text-rose-400">{criticalStudents.length}</p>
          <p className="text-[9px] font-black text-slate-500 uppercase tracking-widest mt-1">Need Help</p>
        </div>
        <div className="bg-[#0f0f11] rounded-2xl p-6 border border-white/5">
          <Trophy className="w-5 h-5 text-[#c5a059] mb-3" />
          <p className="text-3xl font-black text-[#c5a059]">{students.filter(s => s.streak >= 7).length}</p>
          <p className="text-[9px] font-black text-slate-500 uppercase tracking-widest mt-1">7+ Streaks</p>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-3 p-1.5 bg-[#0f0f11] rounded-2xl border border-white/5 w-fit">
        {[{id:'overview', label:'Students'}, {id:'alerts', label:'Alerts'}, {id:'achievements', label:'Achievements'}].map(tab => (
          <button key={tab.id} onClick={() => setActiveTab(tab.id)}
            className={`px-5 py-2.5 rounded-xl text-xs font-black uppercase tracking-widest transition-all ${activeTab === tab.id ? 'bg-[#c5a059] text-black' : 'text-slate-500 hover:text-white'}`}>
            {tab.label}
          </button>
        ))}
      </div>

      {/* Tab Content */}
      {activeTab === 'overview' && (
        <div className="space-y-3">
          {students.map((student, i) => (
            <div key={i} className={`bg-[#0f0f11] rounded-2xl p-6 border transition-all ${student.retention < 30 ? 'border-rose-500/20' : 'border-white/5'}`}>
              <div className="flex items-center gap-4">
                {/* Avatar */}
                <div className={`w-12 h-12 rounded-xl flex items-center justify-center text-lg font-black ${
                  student.status === 'excellent' ? 'bg-[#8da290]/20 text-[#8da290]' :
                  student.status === 'critical' ? 'bg-rose-500/20 text-rose-400' :
                  'bg-[#c5a059]/20 text-[#c5a059]'
                }`}>
                  {student.name.charAt(0)}
                </div>
                
                {/* Info */}
                <div className="flex-1">
                  <div className="flex items-center gap-3">
                    <p className="text-sm font-black text-[#f4f1ea]">{student.name}</p>
                    {student.status === 'critical' && <span className="text-[8px] font-black text-rose-400 bg-rose-500/10 px-2 py-0.5 rounded uppercase">Needs Help</span>}
                    {student.status === 'excellent' && <span className="text-[8px] font-black text-[#8da290] bg-[#8da290]/10 px-2 py-0.5 rounded uppercase">Top Performer</span>}
                  </div>
                  <p className="text-[10px] text-slate-500 mt-1">{student.cards} cards • {student.streak} day streak</p>
                </div>

                {/* Retention */}
                <div className="text-right">
                  <p className={`text-2xl font-black ${student.retention < 30 ? 'text-rose-400' : student.retention > 80 ? 'text-[#8da290]' : 'text-[#c5a059]'}`}>
                    {student.retention}%
                  </p>
                  <p className="text-[9px] text-slate-500">retention</p>
                </div>

                {/* Quiz Score */}
                <div className="text-right">
                  <p className="text-xl font-black text-[#f4f1ea]">{student.quizScore}</p>
                  <p className="text-[9px] text-slate-500">quiz avg</p>
                </div>

                {/* Retention bar */}
                <div className="w-24">
                  <div className="w-full h-2 bg-white/5 rounded-full overflow-hidden">
                    <div className={`h-full rounded-full ${student.retention < 30 ? 'bg-rose-500' : student.retention > 80 ? 'bg-[#8da290]' : 'bg-[#c5a059]'}`} 
                      style={{width: `${student.retention}%`}} />
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {activeTab === 'alerts' && (
        <div className="space-y-3">
          {criticalStudents.length === 0 ? (
            <div className="bg-[#0f0f11] rounded-2xl p-12 border border-white/5 text-center">
              <p className="text-[#8da290] font-serif italic">No critical alerts. All students are on track.</p>
            </div>
          ) : (
            criticalStudents.map((student, i) => (
              <div key={i} className="bg-[#0f0f11] rounded-2xl p-6 border border-rose-500/20">
                <div className="flex items-center gap-4">
                  <AlertTriangle className="w-6 h-6 text-rose-400" />
                  <div className="flex-1">
                    <p className="text-sm font-black text-rose-400">{student.name} — Critical Decay</p>
                    <p className="text-xs text-slate-500 mt-1">Retention at {student.retention}% • No review for 3+ days • {student.cards} cards affected</p>
                  </div>
                  <button className="px-4 py-2 bg-rose-500/10 border border-rose-500/20 rounded-xl text-xs font-black text-rose-400 hover:bg-rose-500/20 transition-all">
                    Contact
                  </button>
                </div>
              </div>
            ))
          )}
          {alerts.length > 0 && alerts.map((alert, i) => (
            <div key={`a${i}`} className="bg-[#0f0f11] rounded-2xl p-6 border border-amber-500/20">
              <div className="flex items-center gap-4">
                <AlertTriangle className="w-5 h-5 text-amber-400" />
                <div className="flex-1">
                  <p className="text-sm font-black text-amber-400">{alert.message}</p>
                  <p className="text-xs text-slate-500 mt-1">{alert.days_critical} days critical • {alert.cards_affected} cards</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {activeTab === 'achievements' && (
        <div className="space-y-3">
          {students.filter(s => s.badges.length > 0).map((student, i) => (
            <div key={i} className="bg-[#0f0f11] rounded-2xl p-6 border border-white/5">
              <div className="flex items-center gap-4 mb-4">
                <div className="w-10 h-10 rounded-xl bg-[#c5a059]/20 flex items-center justify-center">
                  <Award className="w-5 h-5 text-[#c5a059]" />
                </div>
                <div>
                  <p className="text-sm font-black text-[#f4f1ea]">{student.name}</p>
                  <p className="text-[10px] text-slate-500">{student.badges.length} achievements earned</p>
                </div>
              </div>
              <div className="flex flex-wrap gap-2">
                {student.badges.map((badge, j) => (
                  <span key={j} className="px-3 py-1.5 bg-[#c5a059]/10 border border-[#c5a059]/20 rounded-xl text-[10px] font-black text-[#c5a059] uppercase tracking-wider">
                    <Star className="w-3 h-3 inline mr-1" />{badge}
                  </span>
                ))}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default TeacherDashboard;
