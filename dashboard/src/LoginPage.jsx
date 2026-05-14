import React, { useState } from 'react';
import { Brain, User, Lock, BookOpen, GraduationCap } from 'lucide-react';

const API_BASE = "http://127.0.0.1:8000";

const LoginPage = ({ onLogin }) => {
  const [isRegister, setIsRegister] = useState(false);
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [role, setRole] = useState('student');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const endpoint = isRegister ? '/auth/register' : '/auth/login';
      const body = isRegister 
        ? { username, password, role, name: name || username }
        : { username, password };

      const res = await fetch(`${API_BASE}${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });

      const data = await res.json();

      if (res.ok) {
        onLogin(data);
      } else {
        setError(data.detail || 'Login failed');
      }
    } catch (e) {
      setError('Cannot reach server. Is the backend running?');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#0a0a0b] flex items-center justify-center p-6">
      <div className="w-full max-w-md">
        {/* Logo */}
        <div className="flex flex-col items-center mb-10">
          <div className="w-16 h-16 bg-[#c5a059] rounded-2xl flex items-center justify-center mb-4 shadow-[0_0_40px_rgba(197,160,89,0.3)]">
            <Brain className="w-8 h-8 text-black" />
          </div>
          <h1 className="text-3xl font-black text-[#c5a059] font-serif">MemoryForge</h1>
          <p className="text-[10px] font-black tracking-[0.3em] text-[#8da290] uppercase mt-1">Cognitive Operating System</p>
        </div>

        {/* Form */}
        <div className="bg-[#0f0f11] rounded-3xl p-8 border border-white/5 shadow-2xl">
          <h2 className="text-xl font-black text-[#f4f1ea] mb-6 text-center">
            {isRegister ? 'Create Account' : 'Sign In'}
          </h2>

          {error && (
            <div className="mb-4 p-3 bg-rose-500/10 border border-rose-500/20 rounded-xl text-rose-400 text-xs text-center">
              {error}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            {isRegister && (
              <div>
                <label className="text-[9px] font-black text-slate-500 uppercase tracking-widest mb-1 block">Full Name</label>
                <div className="relative">
                  <User className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-600" />
                  <input
                    type="text"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    placeholder="Your name"
                    className="w-full bg-[#0a0a0b] border border-white/10 rounded-2xl pl-12 pr-4 py-3.5 text-[#f4f1ea] placeholder-slate-700 focus:border-[#c5a059]/30 outline-none"
                  />
                </div>
              </div>
            )}

            <div>
              <label className="text-[9px] font-black text-slate-500 uppercase tracking-widest mb-1 block">Username</label>
              <div className="relative">
                <User className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-600" />
                <input
                  type="text"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  placeholder="Enter username"
                  className="w-full bg-[#0a0a0b] border border-white/10 rounded-2xl pl-12 pr-4 py-3.5 text-[#f4f1ea] placeholder-slate-700 focus:border-[#c5a059]/30 outline-none"
                  required
                />
              </div>
            </div>

            <div>
              <label className="text-[9px] font-black text-slate-500 uppercase tracking-widest mb-1 block">Password</label>
              <div className="relative">
                <Lock className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-600" />
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Enter password"
                  className="w-full bg-[#0a0a0b] border border-white/10 rounded-2xl pl-12 pr-4 py-3.5 text-[#f4f1ea] placeholder-slate-700 focus:border-[#c5a059]/30 outline-none"
                  required
                />
              </div>
            </div>

            {isRegister && (
              <div>
                <label className="text-[9px] font-black text-slate-500 uppercase tracking-widest mb-2 block">Role</label>
                <div className="flex gap-3">
                  <button
                    type="button"
                    onClick={() => setRole('student')}
                    className={`flex-1 flex items-center justify-center gap-2 py-3 rounded-2xl border transition-all ${role === 'student' ? 'bg-[#c5a059]/10 border-[#c5a059]/30 text-[#c5a059]' : 'border-white/10 text-slate-500'}`}
                  >
                    <BookOpen className="w-4 h-4" />
                    <span className="text-xs font-black">Student</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => setRole('teacher')}
                    className={`flex-1 flex items-center justify-center gap-2 py-3 rounded-2xl border transition-all ${role === 'teacher' ? 'bg-[#c5a059]/10 border-[#c5a059]/30 text-[#c5a059]' : 'border-white/10 text-slate-500'}`}
                  >
                    <GraduationCap className="w-4 h-4" />
                    <span className="text-xs font-black">Teacher</span>
                  </button>
                </div>
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full py-4 bg-[#c5a059] text-black font-black uppercase text-xs tracking-widest rounded-2xl hover:bg-white transition-all disabled:opacity-50"
            >
              {loading ? 'Processing...' : isRegister ? 'Create Account' : 'Sign In'}
            </button>
          </form>

          <div className="mt-6 text-center">
            <button
              onClick={() => { setIsRegister(!isRegister); setError(''); }}
              className="text-xs text-slate-500 hover:text-[#c5a059] transition-colors"
            >
              {isRegister ? 'Already have an account? Sign In' : "Don't have an account? Register"}
            </button>
          </div>

          {/* Skip login */}
          <div className="mt-6 pt-6 border-t border-white/5 text-center">
            <button
              onClick={() => onLogin({ role: 'independent', user: { username: 'learner', name: 'Independent Learner' } })}
              className="text-xs text-[#8da290] hover:text-[#c5a059] transition-colors font-bold"
            >
              Continue as Independent Learner →
            </button>
            <p className="text-[9px] text-slate-600 mt-2">No account needed. Your data stays local.</p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default LoginPage;
