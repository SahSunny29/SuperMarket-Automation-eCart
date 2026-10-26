"use client";

import React, { useState } from 'react';
import { useRouter } from 'next/navigation';

export default function LoginPage() {
  const router = useRouter();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [showPassword, setShowPassword] = useState(false);

  const handleLogin = (e: React.FormEvent) => {
    e.preventDefault();
    if (username === '12345' && password === '12345') {
      router.push('/dashboard');
    } else {
      setError('Invalid credentials. Use 12345 / 12345.');
    }
  };

  return (
    <main className="w-full min-h-screen grid grid-cols-1 lg:grid-cols-2 relative overflow-hidden bg-[#F8FAFC]">
      {/* LEFT SECTION: Immersive Video Hero */}
      <section aria-label="Brand Overview" className="relative min-h-[440px] lg:min-h-screen flex flex-col justify-between p-8 sm:p-12 xl:p-20 overflow-hidden text-white order-1 lg:order-1">
        <video
          autoPlay
          loop
          muted
          playsInline
          poster="https://images.unsplash.com/photo-1578916171728-46686eac8d58?auto=format&fit=crop&w=1920&q=80"
          className="absolute inset-0 w-full h-full object-cover z-0 pointer-events-none transform scale-105 filter brightness-95"
        >
          <source src="/Login.mp4" type="video/mp4" />
        </video>

        <div className="absolute inset-0 video-overlay-gradient backdrop-blur-[2px] z-10"></div>
        <div className="absolute inset-0 bg-radial from-transparent via-transparent to-black/40 z-10 pointer-events-none"></div>

        <header className="relative z-20 flex items-center gap-3">
          <div className="w-12 h-12 rounded-xl bg-solar-600/90 shadow-lg border border-white/20 flex items-center justify-center p-2 backdrop-blur-md">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="text-white drop-shadow-sm"><circle cx="9" cy="21" r="1"/><circle cx="20" cy="21" r="1"/><path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6"/></svg>
          </div>
          <div className="flex flex-col">
            <span className="text-xs font-semibold uppercase tracking-widest text-solar-200">Retail Automation</span>
            <span className="text-sm font-medium text-slate-300">Enterprise Suite</span>
          </div>
        </header>

        <div className="relative z-20 max-w-xl my-auto py-12">
          <div className="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-white/10 backdrop-blur-md border border-white/20 mb-6 shadow-xl">
             <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="text-white"><circle cx="9" cy="21" r="1"/><circle cx="20" cy="21" r="1"/><path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6"/></svg>
          </div>
          <h1 className="text-4xl sm:text-5xl xl:text-6xl font-extrabold tracking-tight text-white leading-tight mb-3 drop-shadow-md">
            Smart Trolley
          </h1>
          <p className="text-lg sm:text-xl xl:text-2xl font-medium text-slate-200 mb-6 leading-relaxed">
            Smarter Shopping cart Service
          </p>
          <div className="w-24 sm:w-32 h-[2px] bg-gradient-to-r from-solar-500 via-solar-400 to-transparent rounded-full mb-6"></div>
          <p className="text-base sm:text-lg text-slate-300 font-normal leading-relaxed max-w-md">
            The future of retail is in your hands
          </p>
          <div className="mt-8 inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-white/10 backdrop-blur-md border border-white/15 text-xs font-medium text-slate-200">
            <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping"></span>
            <span className="w-2 h-2 rounded-full bg-emerald-500"></span>
            <span>Next-Gen Computer Vision & Sensor Fusion Active</span>
          </div>
        </div>

        <footer className="relative z-20 flex flex-wrap items-center justify-between gap-4 pt-6 border-t border-white/10 text-xs text-slate-400">
          <div>© 2026 Smart Trolley Inc. All rights reserved.</div>
          <div className="flex items-center gap-4">
            <span className="hover:text-slate-200 transition-colors cursor-pointer">Security Protocol v4.8</span>
            <span>•</span>
            <span className="hover:text-slate-200 transition-colors cursor-pointer">Status: Operational</span>
          </div>
        </footer>
      </section>

      {/* RIGHT SECTION: Admin Authentication Form */}
      <section aria-label="Store Admin Login" className="relative min-h-screen bg-[#F8FAFC] flex flex-col justify-between p-6 sm:p-12 xl:p-20 order-2 lg:order-2">
        <div className="w-full flex items-center justify-between text-xs text-slate-500 max-w-md mx-auto mb-6 sm:mb-0">
          <a href="#help" className="inline-flex items-center gap-1.5 text-[#64748B] hover:text-[#0F172A] font-medium transition-colors">
            <svg className="w-4 h-4 text-[#64748B]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            Support & Portal Guide
          </a>
          <div className="flex items-center gap-2">
            <span className="w-2 h-2 rounded-full bg-emerald-500"></span>
            <span className="font-medium text-slate-600">Store Node: US-EAST-01</span>
          </div>
        </div>

        <div className="w-full max-w-md mx-auto my-auto py-8">
          <div className="bg-white rounded-2xl border border-[#E2E8F0] shadow-sm p-8 sm:p-10 relative">
            <div className="absolute top-0 left-8 right-8 h-[3px] bg-gradient-to-r from-solar-500 via-solar-400 to-amber-400 rounded-b"></div>

            <div className="mb-8 pt-2">
              <h2 className="text-2xl sm:text-3xl font-bold text-[#0F172A] tracking-tight">
                Store Admin login
              </h2>
              <p className="text-sm text-[#64748B] mt-2 font-normal leading-relaxed">
                Access your dashboard to manage your storage
              </p>
              {error && <p className="text-sm text-red-500 mt-2 font-medium">{error}</p>}
            </div>

            <form className="space-y-5" onSubmit={handleLogin}>
              <div>
                <label htmlFor="username" className="block text-xs font-semibold text-[#1E293B] uppercase tracking-wider mb-2">
                  Email / Username
                </label>
                <div className="relative rounded-lg shadow-sm">
                  <div className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                    <svg className="h-5 w-5 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                    </svg>
                  </div>
                  <input
                    type="text"
                    id="username"
                    name="username"
                    autoComplete="username"
                    required
                    value={username}
                    onChange={(e) => setUsername(e.target.value)}
                    placeholder="12345"
                    className="block w-full pl-10 pr-4 py-3 bg-[#F8FAFC] border border-[#E2E8F0] rounded-lg text-sm text-[#1E293B] placeholder-slate-400 focus:outline-none focus:bg-white focus:border-solar-600 focus:ring-2 focus:ring-solar-100 transition duration-150 ease-in-out"
                  />
                </div>
              </div>

              <div>
                <label htmlFor="password" className="block text-xs font-semibold text-[#1E293B] uppercase tracking-wider mb-2">
                  Password
                </label>
                <div className="relative rounded-lg shadow-sm">
                  <div className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                    <svg className="h-5 w-5 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                    </svg>
                  </div>
                  <input
                    type={showPassword ? "text" : "password"}
                    id="password"
                    name="password"
                    autoComplete="current-password"
                    required
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="12345"
                    className="block w-full pl-10 pr-10 py-3 bg-[#F8FAFC] border border-[#E2E8F0] rounded-lg text-sm text-[#1E293B] placeholder-slate-400 focus:outline-none focus:bg-white focus:border-solar-600 focus:ring-2 focus:ring-solar-100 transition duration-150 ease-in-out"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    aria-label="Toggle password visibility"
                    className="absolute inset-y-0 right-0 pr-3.5 flex items-center text-slate-400 hover:text-slate-600 focus:outline-none cursor-pointer"
                  >
                    <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      {showPassword ? (
                         <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                      ) : (
                         <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0zM2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                      )}
                    </svg>
                  </button>
                </div>
              </div>

              <div className="flex items-center justify-between pt-1">
                <label className="flex items-center gap-2 cursor-pointer select-none">
                  <input
                    type="checkbox"
                    name="remember"
                    id="remember"
                    className="w-4 h-4 text-solar-600 border-slate-300 rounded focus:ring-solar-400 focus:ring-offset-0 transition cursor-pointer accent-[#E65100]"
                  />
                  <span className="text-xs sm:text-sm font-medium text-[#1E293B]">Remember me</span>
                </label>
                <a href="#forgot-password" className="text-xs sm:text-sm font-semibold text-[#C43D00] hover:text-solar-600 hover:underline transition-colors">
                  Forgot Password?
                </a>
              </div>

              <div className="pt-2">
                <button
                  type="submit"
                  className="w-full h-11 sm:h-12 bg-[#E65100] hover:bg-[#C43D00] active:bg-[#9A3000] text-white text-sm font-semibold rounded-lg shadow-sm hover:shadow-lg focus:outline-none focus:ring-2 focus:ring-solar-200 transition-all duration-150 ease-in-out flex items-center justify-center gap-2 transform active:scale-[0.99] cursor-pointer"
                >
                  <span>Login</span>
                  <svg className="w-4 h-4 text-white/90" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M14 5l7 7m0 0l-7 7m7-7H3" />
                  </svg>
                </button>
              </div>

              <div className="pt-4 text-center">
                <a href="#register" className="inline-flex items-center text-xs sm:text-sm text-[#64748B] hover:text-[#1E293B] font-medium transition-colors">
                  <span>New User?&nbsp;</span>
                  <span className="font-semibold text-[#C43D00] hover:underline">Create Account</span>
                </a>
              </div>
            </form>

            <div className="mt-8 pt-6 border-t border-[#F1F5F9]">
              <div className="flex items-center justify-between text-xs text-slate-400 mb-3">
                <span>Enterprise Single Sign-On</span>
                <span className="px-1.5 py-0.5 rounded bg-slate-100 text-slate-600 font-mono text-[10px]">SAML 2.0 / Okta</span>
              </div>
              <button
                type="button"
                className="w-full h-9 bg-white border border-[#CBD5E1] hover:bg-[#F8FAFC] text-[#1E293B] text-xs font-semibold rounded-lg transition-colors flex items-center justify-center gap-2 cursor-pointer"
              >
                <svg className="w-3.5 h-3.5 text-[#0F172A]" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 14H9v-2h2v2zm0-4H9V7h2v5zm4 4h-2v-2h2v2zm0-4h-2V7h2v5z"/>
                </svg>
                Log in with Corporate SSO
              </button>
            </div>
          </div>
        </div>

        <div className="w-full flex items-center justify-center gap-4 text-[10px] text-slate-400 max-w-md mx-auto mt-6 sm:mt-0 uppercase tracking-wider font-semibold">
          <a href="#terms" className="hover:text-slate-600 transition-colors">Terms of Service</a>
          <span>•</span>
          <a href="#privacy" className="hover:text-slate-600 transition-colors">Privacy Policy</a>
        </div>
      </section>
    </main>
  );
}
