"use client";
import React, { useEffect, useState, Suspense } from 'react';
import { Canvas } from '@react-three/fiber';
import { OrbitControls, useGLTF, Stage, Html, useProgress } from '@react-three/drei';

import storeMapBg from '../Resources/v-1.svg';
import storeSettingsBg from '../Resources/sm.jpeg';


const Loader = () => {
  return <Html center><div className="text-xs font-mono text-slate-500 whitespace-nowrap bg-white/90 backdrop-blur-sm px-4 py-2 rounded-xl shadow-md border border-slate-200/50">Loading WebGL Engine...</div></Html>;
};

const CartModel = () => {
  const { scene } = useGLTF('/shopping_cart.glb');
  return <primitive object={scene} />;
};

const AnimatedCounter = ({ target, isActive, duration = 2000 }: { target: number, isActive: boolean, duration?: number }) => {
  const [count, setCount] = useState(0);

  useEffect(() => {
    if (!isActive) {
      setCount(0);
      return;
    }
    let startTime: number;
    let animationFrame: number;

    const updateCount = (timestamp: number) => {
      if (!startTime) startTime = timestamp;
      const progress = timestamp - startTime;
      const percentage = Math.min(progress / duration, 1);

      const easeOut = 1 - Math.pow(1 - percentage, 4);
      setCount(Math.floor(easeOut * target));

      if (percentage < 1) {
        animationFrame = requestAnimationFrame(updateCount);
      }
    };

    animationFrame = requestAnimationFrame(updateCount);
    return () => cancelAnimationFrame(animationFrame);
  }, [target, duration, isActive]);

  return <>{count}</>;
};

export default function Dashboard() {
  const [isStoreOpen, setIsStoreOpen] = useState(true);
  const [scrolled, setScrolled] = useState(false);
  const [activeSection, setActiveSection] = useState("about-us");
  const [scrollPercent, setScrollPercent] = useState(0);

  // Real-Time Fleet & Security Alert State
  const [securityAlert, setSecurityAlert] = useState<{
    cartId: string;
    message: string;
    timestamp: number;
    status: string;
  } | null>(null);

  const [cartStatuses, setCartStatuses] = useState<Record<string, { status: string; total: number; items: number; user: string }>>({
    CART_01: { status: "IDLE", total: 0.0, items: 0, user: "Unassigned" },
    CART_02: { status: "IDLE", total: 0.0, items: 0, user: "Unassigned" },
  });

  // Persistent Reconnecting WebSocket to /ws/admin
  useEffect(() => {
    let ws: WebSocket | null = null;
    let reconnectTimer: NodeJS.Timeout;
    const wsUrl = process.env.NEXT_PUBLIC_ADMIN_WS_URL || "ws://localhost:8000/ws/admin";

    const connect = () => {
      try {
        ws = new WebSocket(wsUrl);

        ws.onopen = () => {
          console.log("[Dashboard] Connected to Admin WebSocket:", wsUrl);
        };

        ws.onmessage = (event) => {
          try {
            const data = JSON.parse(event.data);
            console.log("[Dashboard] Ingested WS event:", data);

            // 1. Initial Snapshot
            if (data.type === "INITIAL_SNAPSHOT" && Array.isArray(data.carts)) {
              const newMap: Record<string, any> = {};
              data.carts.forEach((c: any) => {
                newMap[c.cart_id] = {
                  status: c.status,
                  total: c.running_total || 0,
                  items: c.items_count || 0,
                  user: c.user_name || "Unassigned",
                };
              });
              setCartStatuses((prev) => ({ ...prev, ...newMap }));
            }

            // 2. High-Priority Security Anomaly (UNSCANNED_DROP / Session Terminated)
            if (data.type === "SECURITY_ALERT" || data.alert_type === "UNSCANNED_DROP" || data.session_terminated) {
              const cartId = data.cart_id || "CART_01";
              setSecurityAlert({
                cartId,
                message: data.message || `SECURITY ALERT: Unscanned item detected on ${cartId}! Session terminated & halted.`,
                timestamp: Date.now(),
                status: "TERMINATED",
              });
              setCartStatuses((prev) => ({
                ...prev,
                [cartId]: {
                  ...(prev[cartId] || {}),
                  status: "TERMINATED",
                  total: 0.0,
                  items: 0,
                },
              }));
            }

            // 3. Cart Paired
            if (data.type === "CART_PAIRED") {
              setCartStatuses((prev) => ({
                ...prev,
                [data.cart_id]: {
                  status: "ACTIVE",
                  total: 0.0,
                  items: 0,
                  user: data.user_name || "Shopper",
                },
              }));
            }

            // 4. Cart Updated
            if (data.type === "CART_UPDATED") {
              setCartStatuses((prev) => ({
                ...prev,
                [data.cart_id]: {
                  ...(prev[data.cart_id] || {}),
                  status: data.status || "ACTIVE",
                  total: data.running_total || 0,
                  items: data.items_count || 0,
                },
              }));
            }

            // 5. Alert Resolved
            if (data.type === "ALERT_RESOLVED") {
              setSecurityAlert(null);
            }
          } catch (e) {
            console.error("[Dashboard] Error parsing WS payload:", e);
          }
        };

        ws.onerror = () => {
          ws?.close();
        };

        ws.onclose = () => {
          reconnectTimer = setTimeout(connect, 3000);
        };
      } catch (err) {
        reconnectTimer = setTimeout(connect, 3000);
      }
    };

    connect();
    return () => {
      clearTimeout(reconnectTimer);
      ws?.close();
    };
  }, []);

  useEffect(() => {
    const handleScroll = () => {
      const scrollY = window.scrollY;
      setScrolled(scrollY > 50);

      const totalDocHeight = document.documentElement.scrollHeight - window.innerHeight;
      const percent = Math.min(100, Math.max(0, (scrollY / totalDocHeight) * 100));
      setScrollPercent(percent);

      const sections = ['about-us', 'store-map', 'store-settings', 'predict-ai', 'troubleshooting'];
      const scrollPos = scrollY + window.innerHeight / 3;
      let currentSection = sections[0];
      sections.forEach(sec => {
        const el = document.getElementById(sec);
        if (el && el.offsetTop <= scrollPos) {
          currentSection = sec;
        }
      });
      setActiveSection(currentSection);
    };

    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  return (
    <>
      {/* Prominent High-Visibility Emergency Security Alert Banner */}
      {securityAlert && (
        <div className="fixed top-24 left-1/2 -translate-x-1/2 z-50 w-[94%] max-w-4xl bg-red-600 text-white px-6 py-4 rounded-2xl shadow-2xl border-2 border-red-300 flex items-center justify-between gap-4 animate-pulse">
          <div className="flex items-center gap-3.5">
            <div className="w-11 h-11 rounded-xl bg-white/20 flex items-center justify-center text-2xl shrink-0">
              <i className="fa-solid fa-triangle-exclamation text-amber-300"></i>
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="font-black text-[11px] uppercase tracking-wider bg-black/40 px-2.5 py-0.5 rounded-full text-white">
                  Security Alert
                </span>
                <span className="font-extrabold text-sm sm:text-base tracking-wide">
                  Trolley {securityAlert.cartId} • Sync Terminated &amp; Halted
                </span>
              </div>
              <p className="text-xs text-red-100 font-medium mt-1">
                {securityAlert.message}
              </p>
            </div>
          </div>
          <button
            onClick={() => setSecurityAlert(null)}
            className="px-4 py-2 rounded-xl bg-white/20 hover:bg-white/30 active:scale-95 text-white font-bold text-xs transition-all shrink-0"
          >
            Acknowledge
          </button>
        </div>
      )}
      {/* Extracted Dashboard Content */}
      {/* ========================================================================= */}
      {/* 1. GLOBAL FLOATING UI ELEMENTS */}
      {/* ========================================================================= */}
      {/* Top Sticky Dynamic Navbar */}
      <header className={`fixed top-0 left-0 right-0 z-50 flex justify-center transition-all duration-300 ease-in pointer-events-none ${scrolled ? "px-4 sm:px-8 pt-3" : "px-0"}`} id="main-navbar-container">
        <nav className={`pointer-events-auto min-h-[64px] backdrop-blur-md border-slate-200/90 px-6 md:px-10 flex items-center justify-between transition-all duration-300 ease-in ${scrolled ? "max-w-6xl h-14 rounded-full border shadow-lg bg-white/90" : "w-full h-[10vh] max-h-[88px] rounded-none border-b bg-white/95 shadow-sm"}`} id="main-navbar">
          {/* Extreme Left: Logo */}
          <a className="flex items-center gap-3.5 group shrink-0" href="#about-us">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-solar-500 to-solar-700 flex items-center justify-center text-white shadow-md shadow-orange-500/20 group-hover:scale-105 transition-transform">
              <i className="fa-solid fa-cart-shopping text-lg"></i>
            </div>
            <div className={`flex-col ${scrolled ? "hidden" : "flex"}`}>
              <span className="font-extrabold text-lg leading-tight tracking-tight text-navy-900 flex items-center gap-1.5">
                Smart Trolley
                <span className="text-[10px] uppercase font-bold tracking-wider px-1.5 py-0.5 rounded bg-solar-50 text-solar-700 border border-solar-200/60">Enterprise</span>
              </span>
              <span className="text-[11px] text-slate-500 font-medium hidden sm:inline-block">Autonomous Retail Grid</span>
            </div>
          </a>
          {/* Center Group: Navigation Items */}
          <div className="hidden lg:flex items-center gap-2 xl:gap-3 bg-slate-100/80 p-1.5 rounded-full border border-slate-200/60 shadow-inner">
            <a className="nav-item text-sm font-semibold px-4 py-2 rounded-full text-slate-700 hover:text-navy-950 hover:bg-white transition-all duration-200" href="#about-us">Home</a>
            <a className="nav-item text-sm font-semibold px-4 py-2 rounded-full text-slate-700 hover:text-navy-950 hover:bg-white transition-all duration-200" href="#store-map">Inventory Map</a>
            <a className="nav-item text-sm font-semibold px-4 py-2 rounded-full text-slate-700 hover:text-navy-950 hover:bg-white transition-all duration-200" href="#store-settings">Aisle Settings</a>
            {/* Special Action Button: Predict AI with animated glowing border */}
            <a className="predict-ai-glow relative text-xs font-bold px-4 py-2 rounded-full bg-gradient-to-r from-solar-500 to-solar-600 text-white border-2 border-solar-400 hover:brightness-110 active:scale-95 transition-all flex items-center gap-1.5 shadow-sm" href="#predict-ai">
              <i className="fa-solid fa-wand-magic-sparkles text-[11px]"></i>
              <span>Predict AI</span>
            </a>
            {/* Status Indicator: Active Customers Data Card */}
            <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-white border border-slate-200 text-xs shadow-2xs">
              <span className="relative flex h-2.5 w-2.5">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-emerald-500"></span>
              </span>
              <span className="text-[11px] font-semibold text-slate-600">Active Customers:</span>
              <span className="font-mono font-bold text-slate-900 bg-emerald-50 text-emerald-700 px-1.5 py-0.5 rounded text-[11px]" id="nav-active-customers">342</span>
            </div>
          </div>
          {/* Mid-Right & Extreme Right Group */}
          <div className="flex items-center gap-3 xl:gap-4 shrink-0">
            {/* Language Switcher */}
            <button className="flex items-center gap-1.5 text-xs font-semibold text-slate-600 hover:text-navy-900 py-1.5 px-2.5 rounded-lg hover:bg-slate-100 transition-colors">
              <i className="fa-solid fa-globe text-slate-400 text-sm"></i>
              <span>EN</span>
            </button>
            {/* Notification Bell (Alerted State) */}
            <button className="relative w-9 h-9 rounded-full flex items-center justify-center text-slate-600 hover:bg-slate-100 hover:text-navy-900 transition-colors">
              <i className="fa-regular fa-bell text-base"></i>
              <span className="absolute top-1.5 right-1.5 w-2.5 h-2.5 rounded-full bg-solar-500 ring-2 ring-white"></span>
            </button>
            {/* Vertical Separator */}
            <div className="h-6 w-px bg-slate-200 hidden sm:block"></div>
            {/* Interactive Oval Toggle Switch (Store Mode: Open/Closed) */}
            <div className="hidden sm:flex items-center gap-2">
              <span className={`text-[11px] font-bold uppercase tracking-wider ${isStoreOpen ? "text-emerald-700" : "text-slate-500"}`} id="store-status-text">{isStoreOpen ? "Open" : "Closed"}</span>
              <button className={`w-12 h-6 rounded-full p-0.5 transition-colors duration-300 relative focus:outline-none shadow-inner ${isStoreOpen ? "bg-emerald-500" : "bg-slate-300"}`} id="store-toggle-btn" onClick={() => setIsStoreOpen(!isStoreOpen)}>
                <div className={`w-5 h-5 rounded-full bg-white shadow-md transform transition-transform duration-300 ${isStoreOpen ? "translate-x-6" : "translate-x-0"}`} id="toggle-knob"></div>
              </button>
            </div>
            {/* Circular User Profile Avatar */}
            <div className="relative group cursor-pointer">
              <div className="w-10 h-10 rounded-full ring-2 ring-solar-500/80 p-0.5 shadow-sm bg-white overflow-hidden flex items-center justify-center">
                <img alt="Admin Profile" className="w-full h-full object-cover rounded-full" src="https://lh3.googleusercontent.com/aida-public/AB6AXuA52f57xLCOP6SR1O3WYanbYgLbUnxwPM7FShk_HCLHOSuSUGol6wOIsJOvbSCwRBl7C1yT34qjzs_sdrCBxZ82Em57hefBbrPfsCBbBn9YIqT0HMWdI-uYSdR9YsuEebyJ-SNpRfT9B6ZaXtgOZxH5WTiqL9vXXRkFaUmxvRcVEOBdcEVfSf2tOcLsDQdD7UFg1epgwTef0fIMTLXxqsV6FQkV-KDa1xfiKMClQZnHr9IBD2RoWUh-" />
              </div>
              <span className="absolute bottom-0 right-0 w-3 h-3 rounded-full bg-emerald-500 ring-2 ring-white"></span>
            </div>
          </div>
        </nav>
      </header>
      {/* Universal Scroll Guide (Right Side) */}
      <aside className="fixed right-[3vw] xl:right-[4vw] top-[32vh] z-40 hidden md:flex flex-col items-end pointer-events-none">
        <div className="relative flex flex-col items-center pointer-events-auto">
          {/* Background Guide Track Line */}
          <div className="absolute top-2 bottom-2 right-[9px] w-[2px] bg-slate-200"></div>
          {/* Dynamic Highlighted Track Fill */}
          <div className="absolute top-2 right-[9px] w-[2px] bg-solar-500 transition-all duration-150" style={{ height: `${scrollPercent}%` }} id="scroll-track-progress"></div>
          {/* Nodes List */}
          <div className="space-y-12 relative z-10">
            {/* Node 1: About Us */}
            <a className="scroll-node group flex items-center gap-3 cursor-pointer select-none" data-section="about-us" href="#about-us">
              <span className={`node-label text-xs transition-colors mix-blend-difference px-2 py-0.5 rounded ${activeSection === "about-us" ? "text-solar-400 font-bold" : "font-semibold text-white/90 group-hover:text-solar-400"}`}>About Us</span>
              <div className={`node-dot w-5 h-5 rounded-full border-2 transition-all duration-300 ${activeSection === "about-us" ? "border-solar-500 bg-solar-500 ring-4 ring-orange-100" : "border-slate-300 bg-white ring-0"}`}></div>
            </a>
            {/* Node 2: Store Map */}
            <a className="scroll-node group flex items-center gap-3 cursor-pointer select-none" data-section="store-map" href="#store-map">
              <span className={`node-label text-xs transition-colors mix-blend-difference px-2 py-0.5 rounded ${activeSection === "store-map" ? "text-solar-400 font-bold" : "font-semibold text-white/90 group-hover:text-solar-400"}`}>Store Map</span>
              <div className={`node-dot w-5 h-5 rounded-full border-2 transition-all duration-300 ${activeSection === "store-map" ? "border-solar-500 bg-solar-500 ring-4 ring-orange-100" : "border-slate-300 bg-white ring-0"}`}></div>
            </a>
            {/* Node 3: Store Settings */}
            <a className="scroll-node group flex items-center gap-3 cursor-pointer select-none" data-section="store-settings" href="#store-settings">
              <span className={`node-label text-xs transition-colors mix-blend-difference px-2 py-0.5 rounded ${activeSection === "store-settings" ? "text-solar-400 font-bold" : "font-semibold text-white/90 group-hover:text-solar-400"}`}>Store Settings</span>
              <div className={`node-dot w-5 h-5 rounded-full border-2 transition-all duration-300 ${activeSection === "store-settings" ? "border-solar-500 bg-solar-500 ring-4 ring-orange-100" : "border-slate-300 bg-white ring-0"}`}></div>
            </a>
            {/* Node 4: Predict AI */}
            <a className="scroll-node group flex items-center gap-3 cursor-pointer select-none" data-section="predict-ai" href="#predict-ai">
              <span className={`node-label text-xs transition-colors mix-blend-difference px-2 py-0.5 rounded ${activeSection === "predict-ai" ? "text-solar-400 font-bold" : "font-semibold text-white/90 group-hover:text-solar-400"}`}>Predict AI</span>
              <div className={`node-dot w-5 h-5 rounded-full border-2 transition-all duration-300 ${activeSection === "predict-ai" ? "border-solar-500 bg-solar-500 ring-4 ring-orange-100" : "border-slate-300 bg-white ring-0"}`}></div>
            </a>
            {/* Node 5: Troubleshooting */}
            <a className="scroll-node group flex items-center gap-3 cursor-pointer select-none" data-section="troubleshooting" href="#troubleshooting">
              <span className={`node-label text-xs transition-colors mix-blend-difference px-2 py-0.5 rounded ${activeSection === "troubleshooting" ? "text-solar-400 font-bold" : "font-semibold text-white/90 group-hover:text-solar-400"}`}>Troubleshooting</span>
              <div className={`node-dot w-5 h-5 rounded-full border-2 transition-all duration-300 ${activeSection === "troubleshooting" ? "border-solar-500 bg-solar-500 ring-4 ring-orange-100" : "border-slate-300 bg-white ring-0"}`}></div>
            </a>
          </div>
        </div>
      </aside>
      {/* ========================================================================= */}
      {/* 2. MAIN SCROLLABLE SECTIONS */}
      {/* ========================================================================= */}
      <main className="w-full">
        {/* SECTION 1: ABOUT US (Hero Section) - min-height 100vh */}
        <section className="relative min-h-screen w-full flex items-center justify-center overflow-hidden bg-navy-950" id="about-us">
          {/* Seamless Looping Supermarket Video Background */}
          <video autoPlay className="absolute inset-0 w-full h-full object-cover pointer-events-none opacity-80" loop muted playsInline>
            <source src="/Hero.mp4" type="video/mp4" />
            {/* Fallback high-res image if video blocked */}
            <img alt="Supermarket Aisle" className="w-full h-full object-cover" src="https://lh3.googleusercontent.com/aida-public/AB6AXuBYxjiNJAMy1RqMa0Rs-EHP7j18IZTFZGPCDXGlYJFQpvuDUoxQVOMf9g-_cZMLXPBMr3ogHgID9QveH_u77BxV5E2BIHh4CLNFZEP3i72GC41zwTz-sYgfcdA9VT_13gyhDBnjq2nyXEdbMDdh0e4iasn9sbAypFJZFzOLOXjTgTaq6PsE0MYSgUG7AdPkYYZuz7keWYUaEmwL2TP6QFeyFQHPsrXpku3xRkkKXMEpxApEMfoeSzmY" />
          </video>
          {/* Gradient Atmospheric Overlay */}
          <div className="absolute inset-0 bg-gradient-to-t from-navy-950/80 via-navy-950/30 to-transparent pointer-events-none"></div>
          {/* Centered Hero Content */}
          <div className="relative z-10 max-w-4xl mx-auto px-6 text-center pt-24 pb-16 flex flex-col items-center">
            {/* Telemetry Badge */}
            <div className="inline-flex items-center gap-2.5 px-4 py-1.5 rounded-full bg-white/10 backdrop-blur-md border border-white/20 text-white text-xs font-semibold mb-6 shadow-xl animate-pulse">
              <span className="w-2 h-2 rounded-full bg-solar-500"></span>
              <span>Next-Generation Autonomous Retail Platform</span>
            </div>
            {/* Main Title & Subtitle Required by Spec */}
            <div className="p-8 md:p-12 rounded-3xl bg-navy-900/60 backdrop-blur-md border border-white/10 shadow-2xl max-w-3xl">
              <h1 className="text-4xl sm:text-5xl md:text-6xl font-extrabold text-white tracking-tight leading-tight drop-shadow-lg">Smart Trolley Enterprise</h1>
              <p className="mt-4 text-sm text-slate-400 max-w-xl mx-auto leading-relaxed">
                Smart Trolley replaces friction at checkout with weight sensor fusion, computer vision, and real-time localized edge computing directly onboard grocery trolleys.
              </p>
              <div className="mt-8 flex flex-wrap justify-center items-center gap-4">
                <a className="px-6 py-3 rounded-xl bg-solar-600 hover:bg-solar-700 text-white font-semibold text-sm shadow-lg shadow-orange-600/30 transition-all flex items-center gap-2" href="#store-map">
                  <span>Explore Interactive Map</span>
                  <i className="fa-solid fa-arrow-down text-xs"></i>
                </a>
                <a className="px-6 py-3 rounded-xl bg-white/10 hover:bg-white/20 text-white font-semibold text-sm backdrop-blur border border-white/20 transition-all flex items-center gap-2" href="#predict-ai">
                  <i className="fa-solid fa-microchip text-solar-400"></i>
                  <span>View AI Telemetry</span>
                </a>
              </div>
            </div>
            {/* Scroll Indicator Down Prompt */}
            <div className="mt-12 flex flex-col items-center text-slate-400 text-xs font-medium">
              <span className="mb-2 uppercase tracking-widest text-[10px]">Scroll Down</span>
              <div className="w-6 h-10 rounded-full border-2 border-white/30 flex items-start justify-center p-1.5">
                <div className="w-1.5 h-2.5 bg-solar-500 rounded-full animate-bounce"></div>
              </div>
            </div>
          </div>
        </section>
        {/* SECTION 2: STORE MAP - PANORAMIC 100% VIEWPORT WITH INTEGRATED TOP FILTER BAR (FROM SCREEN_2) */}
        <section className="min-h-[90vh] py-10 px-6 md:px-12 lg:px-16 max-w-[1720px] mx-auto flex flex-col justify-center relative bg-navy-950" id="store-map" style={{ backgroundImage: `url(${storeMapBg.src})`, backgroundSize: 'cover', backgroundPosition: 'center' }}>
          {/* Section Header with Spatial Telemetry Meta */}
          <div className="flex flex-col md:flex-row md:items-end justify-between mb-4">
            <div>
              <span className="text-xs font-bold uppercase tracking-wider text-solar-600">Spatial Telemetry</span>
              <h2 className="text-2xl md:text-3xl font-extrabold text-navy-900 tracking-tight">Interactive Store Map &amp; Geo-Inventory</h2>
            </div>
            <div className="mt-3 md:mt-0 flex items-center gap-4 text-xs text-slate-500 font-medium">
              <span className="flex items-center gap-1.5"><span className="w-2.5 h-2.5 rounded-sm bg-solar-500"></span> High Density</span>
              <span className="flex items-center gap-1.5"><span className="w-2.5 h-2.5 rounded-sm bg-navy-800"></span> Structural Fixture</span>
              <span className="flex items-center gap-1.5"><span className="w-2.5 h-2.5 rounded-sm bg-emerald-500"></span> POS Station</span>
              <span className="text-slate-300">|</span>
              <span>Floor Load: <strong>72%</strong></span>
              <span className="text-emerald-600 font-semibold flex items-center gap-1"><i className="fa-solid fa-wifi text-[10px]"></i> Beacon Sync Ok</span>
            </div>
          </div>
          {/* Active Fleet Grid & Real-Time Sync Monitor */}
          <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-4 mb-4">
            {Object.entries(cartStatuses).map(([cartId, data]) => {
              const isTerminated = data.status === "TERMINATED";
              const isActive = data.status === "ACTIVE";
              return (
                <div
                  key={cartId}
                  className={`p-3.5 rounded-2xl border transition-all ${
                    isTerminated
                      ? "bg-red-50 border-red-300 shadow-md shadow-red-500/10"
                      : isActive
                      ? "bg-emerald-50 border-emerald-300 shadow-sm"
                      : "bg-white border-slate-200"
                  }`}
                >
                  <div className="flex items-center justify-between">
                    <span className="font-extrabold text-xs text-navy-900 flex items-center gap-1.5">
                      <i className={`fa-solid fa-cart-shopping ${isTerminated ? "text-red-500" : isActive ? "text-emerald-500" : "text-slate-400"}`}></i>
                      {cartId}
                    </span>
                    <span
                      className={`text-[10px] font-bold px-2 py-0.5 rounded-full uppercase tracking-wider ${
                        isTerminated
                          ? "bg-red-600 text-white animate-pulse"
                          : isActive
                          ? "bg-emerald-500 text-white"
                          : "bg-slate-200 text-slate-600"
                      }`}
                    >
                      {isTerminated ? "TERMINATED" : data.status}
                    </span>
                  </div>
                  <div className="mt-2 flex items-center justify-between text-[11px] text-slate-500 font-medium">
                    <span>Items: <strong className="text-slate-800">{data.items}</strong></span>
                    <span>Total: <strong className="text-slate-800">Rs. {Number(data.total).toFixed(2)}</strong></span>
                  </div>
                  {isTerminated && (
                    <p className="mt-1.5 text-[10px] font-bold text-red-600 flex items-center gap-1">
                      <i className="fa-solid fa-triangle-exclamation"></i> Sync Halted (Unscanned Drop)
                    </p>
                  )}
                </div>
              );
            })}
          </div>
          {/* Integrated Horizontal Top Filter Bar */}
          <div className="bg-white rounded-2xl border border-slate-200 shadow-sm p-3 mb-4 flex flex-col lg:flex-row items-center justify-between gap-3">
            {/* Search Input */}
            <div className="relative w-full lg:w-72 shrink-0">
              <i className="fa-solid fa-magnifying-glass absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400 text-xs"></i>
              <input className="w-full pl-9 pr-3.5 py-2 text-xs font-medium rounded-xl bg-slate-50 border border-slate-200 focus:outline-none focus:ring-2 focus:ring-solar-500 focus:bg-white transition-all" placeholder="Search aisle, category..." type="text" />
            </div>
            {/* Horizontal Filter Buttons Track */}
            <div className="flex items-center gap-2 overflow-x-auto w-full py-1 scrollbar-none">
              <button className="shrink-0 px-3.5 py-2 rounded-xl bg-solar-50 text-solar-700 font-semibold text-xs border border-solar-200 flex items-center gap-2 transition-all">
                <i className="fa-solid fa-apple-whole text-solar-500"></i>
                <span>Produce &amp; Organic (Category 1)</span>
                <span className="bg-solar-100 text-solar-700 text-[10px] font-bold px-1.5 py-0.5 rounded-full">48 SKU</span>
              </button>
              <button className="shrink-0 px-3.5 py-2 rounded-xl hover:bg-slate-50 text-slate-700 font-medium text-xs border border-slate-200/70 flex items-center gap-2 transition-all">
                <i className="fa-solid fa-cheese text-slate-400"></i>
                <span>Dairy &amp; Refrigerated (Category 2)</span>
                <span className="text-slate-400 text-[10px]">36 SKU</span>
              </button>
              <button className="shrink-0 px-3.5 py-2 rounded-xl hover:bg-slate-50 text-slate-700 font-medium text-xs border border-slate-200/70 flex items-center gap-2 transition-all">
                <i className="fa-solid fa-bread-slice text-slate-400"></i>
                <span>Bakery &amp; Dry Grains (Category 3)</span>
                <span className="text-slate-400 text-[10px]">52 SKU</span>
              </button>
              <button className="shrink-0 px-3.5 py-2 rounded-xl hover:bg-slate-50 text-slate-700 font-medium text-xs border border-slate-200/70 flex items-center gap-2 transition-all">
                <i className="fa-solid fa-wine-bottle text-slate-400"></i>
                <span>Beverages &amp; Snacks (Category 4)</span>
                <span className="text-slate-400 text-[10px]">64 SKU</span>
              </button>
              <button className="shrink-0 px-3.5 py-2 rounded-xl hover:bg-slate-50 text-slate-700 font-medium text-xs border border-slate-200/70 flex items-center gap-2 transition-all">
                <i className="fa-solid fa-pump-soap text-slate-400"></i>
                <span>Personal Care &amp; Home (Category 5)</span>
                <span className="text-slate-400 text-[10px]">29 SKU</span>
              </button>
            </div>
          </div>
          {/* Panoramic Full-Width Store Map Canvas Container */}
          <div className="bg-white rounded-2xl border border-slate-200 shadow-sm p-6 relative flex flex-col justify-between overflow-visible">
            {/* Abstract SVG Grid Background with smooth transition */}
            <div className="absolute inset-0 rounded-2xl overflow-hidden pointer-events-none opacity-40">
              <svg className="w-full h-full" height="100%" width="100%" xmlns="http://www.w3.org/2000/svg">
                <defs>
                  <pattern height="40" id="store-grid-panoramic" patternUnits="userSpaceOnUse" width="40">
                    <rect fill="none" height="40" width="40"></rect>
                    <path d="M 40 0 L 0 0 0 40" fill="none" stroke="#E2E8F0" strokeWidth="1"></path>
                    <circle cx="20" cy="20" fill="#CBD5E1" r="1.5"></circle>
                  </pattern>
                </defs>
                <rect fill="url(#store-grid-panoramic)" height="100%" width="100%"></rect>
              </svg>
            </div>
            {/* Store Map Geometry Layout Canvas */}
            <div className="relative w-full h-[540px] rounded-xl border border-slate-200/70 bg-slate-50/70 p-6 flex flex-col justify-between">
              {/* Shelf 1 (Wide horizontal top shelf) */}
              <div className="shelf-item relative w-full h-16 bg-navy-900 rounded-lg shadow-md border-2 border-navy-800 flex items-center justify-center cursor-pointer transition-all hover:border-solar-500 group">
                <span className="text-white text-xs font-bold tracking-wider uppercase flex items-center gap-2">
                  <i className="fa-solid fa-boxes-stacked text-solar-400"></i>
                  Shelf 1: Premium Organics &amp; Dry Produce
                </span>
                {/* Tooltip Popover */}
                <div className="shelf-tooltip opacity-0 pointer-events-none absolute -top-16 left-1/2 -translate-x-1/2 bg-navy-950 text-white px-4 py-2 rounded-lg text-xs shadow-xl border border-solar-500/40 transition-all duration-200 z-30 whitespace-nowrap">
                  <p className="font-bold text-solar-400">Organic Honey Crisp Apples (SKU-104)</p>
                  <p className="text-[11px] text-slate-300">Stock: <span className="font-bold text-emerald-400">148 units</span> · Restocked 2h ago</p>
                </div>
              </div>
              {/* Middle Tier Layout (Shelf 2 Vertical, Shelf 3 & 4 Horizontal, Bill Counter) */}
              <div className="grid grid-cols-12 gap-6 h-[340px] my-4 items-stretch">
                {/* Shelf 2 (Tall vertical left shelf) */}
                <div className="shelf-item col-span-3 bg-navy-800 rounded-lg shadow-md border-2 border-navy-700 flex flex-col items-center justify-center cursor-pointer hover:border-solar-500 transition-all relative group p-3 text-center">
                  <i className="fa-solid fa-snowflake text-cyan-400 text-xl mb-2"></i>
                  <span className="text-white text-xs font-bold uppercase tracking-wider leading-relaxed">
                    Shelf 2<br /><span className="text-[10px] text-slate-300 font-normal">Refrigerated Dairy &amp; Artisan Cheeses</span>
                  </span>
                  {/* Tooltip Popover */}
                  <div className="shelf-tooltip opacity-0 pointer-events-none absolute top-1/2 left-full ml-3 -translate-y-1/2 bg-navy-950 text-white px-4 py-2 rounded-lg text-xs shadow-xl border border-solar-500/40 transition-all duration-200 z-30 whitespace-nowrap">
                    <p className="font-bold text-solar-400">Organic Whole Milk 1gal (SKU-209)</p>
                    <p className="text-[11px] text-slate-300">Stock: <span className="font-bold text-amber-400">18 units (Low Stock)</span></p>
                  </div>
                </div>
                {/* Shelf 3 & Shelf 4 Center Group */}
                <div className="col-span-6 flex flex-col justify-between gap-4">
                  {/* Shelf 3 */}
                  <div className="shelf-item flex-1 bg-white rounded-lg shadow-sm border-2 border-slate-300 hover:border-solar-500 flex items-center justify-between px-6 cursor-pointer transition-all relative group">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded bg-solar-50 text-solar-600 flex items-center justify-center font-bold text-xs">S3</div>
                      <span className="text-navy-900 text-xs font-bold">Shelf 3: Bakery &amp; Artisanal Breads</span>
                    </div>
                    <span className="text-[11px] font-semibold text-slate-500">Row A-04</span>
                    {/* Tooltip */}
                    <div className="shelf-tooltip opacity-0 pointer-events-none absolute -top-14 left-1/2 -translate-x-1/2 bg-navy-950 text-white px-4 py-2 rounded-lg text-xs shadow-xl border border-solar-500/40 transition-all duration-200 z-30 whitespace-nowrap">
                      <p className="font-bold text-solar-400">Sourdough Loaf (SKU-312)</p>
                      <p className="text-[11px] text-slate-300">Stock: <span className="font-bold text-emerald-400">54 units</span></p>
                    </div>
                  </div>
                  {/* Shelf 4 */}
                  <div className="shelf-item flex-1 bg-white rounded-lg shadow-sm border-2 border-slate-300 hover:border-solar-500 flex items-center justify-between px-6 cursor-pointer transition-all relative group">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded bg-solar-50 text-solar-600 flex items-center justify-center font-bold text-xs">S4</div>
                      <span className="text-navy-900 text-xs font-bold">Shelf 4: Packaged Snacks &amp; Cereals</span>
                    </div>
                    <span className="text-[11px] font-semibold text-slate-500">Row B-01</span>
                    {/* Tooltip */}
                    <div className="shelf-tooltip opacity-0 pointer-events-none absolute -bottom-14 left-1/2 -translate-x-1/2 bg-navy-950 text-white px-4 py-2 rounded-lg text-xs shadow-xl border border-solar-500/40 transition-all duration-200 z-30 whitespace-nowrap">
                      <p className="font-bold text-solar-400">Granola Protein Clusters (SKU-450)</p>
                      <p className="text-[11px] text-slate-300">Stock: <span className="font-bold text-emerald-400">92 units</span></p>
                    </div>
                  </div>
                </div>
                {/* Bill Counter (Small box) */}
                <div className="shelf-item col-span-3 bg-gradient-to-br from-emerald-600 to-teal-700 rounded-lg shadow-md border-2 border-emerald-500 flex flex-col items-center justify-center cursor-pointer transition-all hover:scale-98 relative group text-center p-3">
                  <i className="fa-solid fa-receipt text-white text-2xl mb-2"></i>
                  <span className="text-white text-xs font-bold uppercase tracking-wider">
                    Bill Counter
                  </span>
                  <span className="text-[10px] text-emerald-100 font-medium mt-1">Autonomous Sensor Gate #01</span>
                  {/* Tooltip */}
                  <div className="shelf-tooltip opacity-0 pointer-events-none absolute bottom-full mb-3 left-1/2 -translate-x-1/2 bg-navy-950 text-white px-4 py-2 rounded-lg text-xs shadow-xl border border-emerald-400/40 transition-all duration-200 z-30 whitespace-nowrap">
                    <p className="font-bold text-emerald-300">Instant RFID &amp; Weight Reconcile</p>
                    <p className="text-[11px] text-slate-300">Throughput: <span className="font-bold text-white">4.2 sec/customer</span></p>
                  </div>
                </div>
              </div>
              {/* Floor Status Bar */}
              <div className="flex items-center justify-between text-[11px] text-slate-400 px-2">
                <span>Main Entry Turnstile (West Wing)</span>
                <span>Emergency Exit &amp; Loading Dock (North-East)</span>
              </div>
            </div>
            {/* OVERLAY BUTTON: "Add Product" sticking out at absolute bottom-right */}
            <div className="absolute -bottom-5 -right-5 z-20">
              <button className="px-6 py-3.5 rounded-2xl bg-solar-600 hover:bg-solar-700 active:scale-95 text-white font-bold text-xs uppercase tracking-wider shadow-xl shadow-orange-600/40 border-2 border-white flex items-center gap-2.5 transition-all">
                <i className="fa-solid fa-circle-plus text-base"></i>
                <span>Add Product</span>
              </button>
            </div>
          </div>
        </section>
        {/* SECTION 3: STORE SETTINGS - Usable height 90vh */}
        <section className="min-h-[90vh] py-12 px-6 md:px-12 lg:px-16 max-w-[1720px] mx-auto flex flex-col justify-center relative overflow-hidden" id="store-settings">
          {/* Animated Background: Supermarket Aisle with Atmospheric Blur */}
          <div className="absolute inset-0 rounded-3xl overflow-hidden -z-10 shadow-lg border border-slate-200/80">
            <img alt="Supermarket Aisle" className="w-full h-full object-cover filter brightness-[0.35] contrast-105 scale-105 transition-transform duration-1000 ease-out hover:scale-100" src={storeSettingsBg.src} />
            <div className="absolute inset-0 bg-gradient-to-b from-navy-950/80 via-navy-900/60 to-navy-950/90"></div>
          </div>
          {/* Section Title Header */}
          <div className="relative z-10 text-center mb-8">
            <span className="text-xs font-bold uppercase tracking-widest text-solar-400">Aisle Operations &amp; Node Tuning</span>
            <h2 className="text-3xl md:text-4xl font-extrabold text-white tracking-tight mt-1">Store Hardware &amp; System Placards</h2>
            <p className="text-xs md:text-sm text-slate-300 mt-2">Hover over any hanging flyer to inspect hardware configurations and calibrate telemetry.</p>
          </div>
          {/* Hanging Flyers Container */}
          <div className="relative z-10 grid grid-cols-1 md:grid-cols-3 gap-8 items-start pt-6 max-w-5xl mx-auto w-full">
            {/* FLYER 1: Inventory Placard */}
            <div className="hanging-sway-1 group relative flex flex-col items-center">
              {/* Hanging String Line */}
              <div className="w-[2px] h-12 bg-gradient-to-b from-slate-400 to-slate-200"></div>
              {/* Eyelet / Ring */}
              <div className="w-3.5 h-3.5 rounded-full border-2 border-slate-200 bg-navy-900 mb-1"></div>
              {/* Placard Card: Expands downward on hover */}
              <div className="w-full bg-white rounded-2xl shadow-2xl border border-slate-200/90 p-6 flex flex-col justify-between transition-all duration-500 ease-out max-h-[220px] group-hover:max-h-[460px] overflow-hidden group-hover:shadow-orange-500/20 group-hover:border-solar-400">
                {/* Normal Header State */}
                <div className="flex flex-col items-center gap-3 text-center">
                  <div className="w-12 h-12 rounded-xl bg-orange-50 text-solar-600 flex items-center justify-center font-bold text-xl">
                    <i className="fa-solid fa-boxes-stacked"></i>
                  </div>
                  <div className="flex flex-col items-center">
                    <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Aisle Node 01</span>
                    <h3 className="text-base font-extrabold text-navy-900">Inventory</h3>
                  </div>
                </div>
                <p className="text-xs text-slate-600 mt-3 line-clamp-2 text-center">
                  Automated tare-weight calibration and shelf restock trigger threshold controls.
                </p>
                {/* Expanded State Details (Visible on Hover) */}
                <div className="opacity-0 group-hover:opacity-100 transition-opacity duration-300 pt-4 space-y-3">
                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-200/70 text-xs">
                    <div className="flex justify-between py-1 border-b border-slate-200/40">
                      <span className="text-slate-500 flex items-center gap-1.5"><i className="fa-solid fa-chart-pie"></i> Auto-Refill:</span>
                      <span className="font-bold text-navy-900">15% Max Capacity</span>
                    </div>
                    <div className="flex justify-between py-1">
                      <span className="text-slate-500 flex items-center gap-1.5"><i className="fa-solid fa-scale-balanced"></i> Tare Calibration:</span>
                      <span className="font-bold text-emerald-600">Active (±2g tolerance)</span>
                    </div>
                  </div>
                  <p className="text-[11px] text-slate-500">Directly syncs with supply chain warehouse ERP protocol SAP-v4.</p>
                </div>
                {/* Distinct Action Button anchored firmly to the bottom */}
                <div className="mt-4 pt-3 border-t border-slate-100 shrink-0">
                  <button className="w-full py-2.5 rounded-xl bg-navy-900 hover:bg-navy-800 text-white font-semibold text-xs transition-colors flex items-center justify-center gap-2">
                    <span>Manage Inventory Settings</span>
                    <i className="fa-solid fa-arrow-right text-[10px]"></i>
                  </button>
                </div>
              </div>
            </div>
            {/* FLYER 2: System Settings Placard (Staggered Height) */}
            <div className="hanging-sway-2 group relative flex flex-col items-center md:pt-6">
              {/* Hanging String Line */}
              <div className="w-[2px] h-20 bg-gradient-to-b from-slate-400 to-slate-200"></div>
              {/* Eyelet / Ring */}
              <div className="w-3.5 h-3.5 rounded-full border-2 border-slate-200 bg-navy-900 mb-1"></div>
              {/* Placard Card */}
              <div className="w-full bg-white rounded-2xl shadow-2xl border border-slate-200/90 p-6 flex flex-col justify-between transition-all duration-500 ease-out max-h-[220px] group-hover:max-h-[460px] overflow-hidden group-hover:shadow-orange-500/20 group-hover:border-solar-400">
                <div className="flex flex-col items-center gap-3 text-center">
                  <div className="w-12 h-12 rounded-xl bg-teal-50 text-teal-600 flex items-center justify-center font-bold text-xl">
                    <i className="fa-solid fa-sliders"></i>
                  </div>
                  <div className="flex flex-col items-center">
                    <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Core Firmware</span>
                    <h3 className="text-base font-extrabold text-navy-900">System Settings</h3>
                  </div>
                </div>
                <p className="text-xs text-slate-600 mt-3 line-clamp-2 text-center">
                  Optical barcode scan intervals, LiDAR perimeter guard, and emergency brake override.
                </p>
                {/* Expanded State Details */}
                <div className="opacity-0 group-hover:opacity-100 transition-opacity duration-300 pt-4 space-y-3">
                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-200/70 text-xs">
                    <div className="flex justify-between py-1 border-b border-slate-200/40">
                      <span className="text-slate-500 flex items-center gap-1.5"><i className="fa-solid fa-gauge-high"></i> Scan Frequency:</span>
                      <span className="font-bold text-navy-900">60 FPS Vision Track</span>
                    </div>
                    <div className="flex justify-between py-1">
                      <span className="text-slate-500 flex items-center gap-1.5"><i className="fa-solid fa-shield-halved"></i> Geofence Guard:</span>
                      <span className="font-bold text-emerald-600">Locked to Perimeter</span>
                    </div>
                  </div>
                  <p className="text-[11px] text-slate-500">Battery failsafe activates automatic wheel lock outside retail perimeter.</p>
                </div>
                {/* Anchored Action Button */}
                <div className="mt-4 pt-3 border-t border-slate-100 shrink-0">
                  <button className="w-full py-2.5 rounded-xl bg-solar-600 hover:bg-solar-700 text-white font-semibold text-xs transition-colors flex items-center justify-center gap-2">
                    <span>Configure Firmware</span>
                    <i className="fa-solid fa-gear text-[10px]"></i>
                  </button>
                </div>
              </div>
            </div>
            {/* FLYER 3: Staff Info Placard */}
            <div className="hanging-sway-3 group relative flex flex-col items-center md:pt-2">
              {/* Hanging String Line */}
              <div className="w-[2px] h-14 bg-gradient-to-b from-slate-400 to-slate-200"></div>
              {/* Eyelet / Ring */}
              <div className="w-3.5 h-3.5 rounded-full border-2 border-slate-200 bg-navy-900 mb-1"></div>
              {/* Placard Card */}
              <div className="w-full bg-white rounded-2xl shadow-2xl border border-slate-200/90 p-6 flex flex-col justify-between transition-all duration-500 ease-out max-h-[220px] group-hover:max-h-[460px] overflow-hidden group-hover:shadow-orange-500/20 group-hover:border-solar-400">
                <div className="flex flex-col items-center gap-3 text-center">
                  <div className="w-12 h-12 rounded-xl bg-purple-50 text-purple-600 flex items-center justify-center font-bold text-xl">
                    <i className="fa-solid fa-users-gear"></i>
                  </div>
                  <div className="flex flex-col items-center">
                    <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Duty Roster</span>
                    <h3 className="text-base font-extrabold text-navy-900">Staff Info</h3>
                  </div>
                </div>
                <p className="text-xs text-slate-600 mt-3 line-clamp-2 text-center">
                  Floor assistance dispatch, technician on-call routing, and supervisory override badges.
                </p>
                {/* Expanded State Details */}
                <div className="opacity-0 group-hover:opacity-100 transition-opacity duration-300 pt-4 space-y-3">
                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-200/70 text-xs">
                    <div className="flex justify-between py-1 border-b border-slate-200/40">
                      <span className="text-slate-500 flex items-center gap-1.5"><i className="fa-solid fa-user-tie"></i> Supervisors:</span>
                      <span className="font-bold text-navy-900">4 Staff on Deck</span>
                    </div>
                    <div className="flex justify-between py-1">
                      <span className="text-slate-500 flex items-center gap-1.5"><i className="fa-solid fa-stopwatch"></i> Incident Response:</span>
                      <span className="font-bold text-emerald-600">38 seconds</span>
                    </div>
                  </div>
                  <p className="text-[11px] text-slate-500">Push notifications broadcast to smart badge handheld units instantly.</p>
                </div>
                {/* Anchored Action Button */}
                <div className="mt-4 pt-3 border-t border-slate-100 shrink-0">
                  <button className="w-full py-2.5 rounded-xl bg-navy-900 hover:bg-navy-800 text-white font-semibold text-xs transition-colors flex items-center justify-center gap-2">
                    <span>View Staff Roster</span>
                    <i className="fa-solid fa-user-check text-[10px]"></i>
                  </button>
                </div>
              </div>
            </div>
          </div>
        </section>
        {/* SECTION 4: PREDICT AI - Usable height 90vh */}
        <section className="min-h-[90vh] py-10 px-6 md:px-12 lg:px-16 max-w-[1720px] mx-auto flex flex-col justify-between" id="predict-ai">
          {/* Section Title */}
          <div className="flex items-center justify-between mb-4">
            <div>
              <span className="text-xs font-bold uppercase tracking-wider text-solar-600">Predictive Neural Telemetry</span>
              <h2 className="text-2xl md:text-3xl font-extrabold text-navy-900 tracking-tight">Predict AI: Real-Time Footfall &amp; Demand Engine</h2>
            </div>
            <div className="hidden sm:flex items-center gap-2 bg-white px-3 py-1.5 rounded-xl border border-slate-200 text-xs shadow-2xs">
              <i className="fa-solid fa-bolt text-solar-500"></i>
              <span className="text-slate-500">Inference Latency:</span>
              <span className="font-mono font-bold text-slate-800">12ms</span>
            </div>
          </div>
          {/* Top Container (75% height) */}
          <div className="grid grid-cols-1 lg:grid-cols-10 gap-6 h-[460px] items-stretch">
            {/* Left (Graph Card): 60% (6 cols) - Dark themed card */}
            <div className="lg:col-span-6 bg-navy-950 rounded-2xl border border-navy-800 shadow-xl p-6 flex flex-col justify-between relative overflow-hidden">
              <div className="flex items-center justify-between relative z-10">
                <div>
                  <span className="text-[11px] font-bold text-solar-400 uppercase tracking-wider">Dynamic Load Analysis</span>
                  <h3 className="text-lg font-bold text-white tracking-tight">Customer nos vs time</h3>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-[11px] text-slate-400 bg-navy-900 px-2.5 py-1 rounded-md border border-navy-800">Today: 08:00 - 22:00</span>
                  <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
                </div>
              </div>
              {/* Line Graph SVG with Ease-in Stroke Drawing Animation */}
              <div className="relative w-full h-[320px] my-2 flex items-center justify-center">
                <svg className="w-full h-full" id="ai-graph-svg" preserveAspectRatio="none" viewBox="0 0 700 280">
                  <defs>
                    <linearGradient id="orangeGraphGrad" x1="0%" x2="0%" y1="0%" y2="100%">
                      <stop offset="0%" stopColor="#FF6400" stopOpacity="0.35"></stop>
                      <stop offset="100%" stopColor="#FF6400" stopOpacity="0.0"></stop>
                    </linearGradient>
                  </defs>
                  {/* Subtle Grid lines */}
                  <line stroke="#1E293B" strokeDasharray="4 4" strokeWidth="1" x1="0" x2="700" y1="50" y2="50"></line>
                  <line stroke="#1E293B" strokeDasharray="4 4" strokeWidth="1" x1="0" x2="700" y1="120" y2="120"></line>
                  <line stroke="#1E293B" strokeDasharray="4 4" strokeWidth="1" x1="0" x2="700" y1="190" y2="190"></line>
                  <line stroke="#334155" strokeWidth="1" x1="0" x2="700" y1="260" y2="260"></line>
                  {/* Gradient Fill Area */}
                  <path d="M 0 240 Q 90 220 180 160 T 360 80 T 520 130 T 700 40 L 700 260 L 0 260 Z" fill="url(#orangeGraphGrad)"></path>
                  {/* Animated Main Line */}
                  <path className="line-draw-anim" d="M 0 240 Q 90 220 180 160 T 360 80 T 520 130 T 700 40" fill="none" id="graph-stroke-path" stroke="#FF6400" strokeLinecap="round" strokeWidth="4"></path>
                  {/* Milestone Anchor Points */}
                  <circle cx="180" cy="160" fill="#FFFFFF" r="5" stroke="#FF6400" strokeWidth="3"></circle>
                  <circle cx="360" cy="80" fill="#FFFFFF" r="6" stroke="#FB923C" strokeWidth="3"></circle>
                  <circle cx="520" cy="130" fill="#FFFFFF" r="5" stroke="#FF6400" strokeWidth="3"></circle>
                  <circle cx="700" cy="40" fill="#FFFFFF" r="6" stroke="#FF6400" strokeWidth="3"></circle>
                  {/* Peak Label */}
                  <text fill="#FED7AA" fontFamily="Inter" fontSize="12" fontWeight="bold" textAnchor="middle" x="360" y="60">Peak: 540 shoppers @ 17:30</text>
                </svg>
              </div>
              {/* Bottom Axis Labels */}
              <div className="flex justify-between text-[11px] font-mono text-slate-400 border-t border-navy-800 pt-2">
                <span>08:00 AM</span>
                <span>11:00 AM</span>
                <span>02:00 PM</span>
                <span>05:30 PM (Peak)</span>
                <span>08:00 PM</span>
                <span>10:00 PM</span>
              </div>
            </div>
            {/* Right (Video Card): 40% (4 cols) - Demand Forecasting Video Card with Glowing Button */}
            <div className="lg:col-span-4 bg-navy-900 rounded-2xl border border-navy-800 shadow-xl relative overflow-hidden flex flex-col justify-between group">
              {/* Background Video Player */}
              <video autoPlay className="absolute inset-0 w-full h-full object-cover filter brightness-50 contrast-110 group-hover:scale-105 transition-transform duration-700" loop muted playsInline>
                <source src="https://assets.mixkit.co/videos/preview/mixkit-hands-of-a-person-choosing-a-product-at-the-supermarket-41314-large.mp4" type="video/mp4" />
                <img alt="Supermarket forecasting" src="https://lh3.googleusercontent.com/aida-public/AB6AXuAyx2j-REl_OHZB3jjYWSAOPmhmMYcz16pHAqhzQ0f9EBLZ-9Qlwl8A5HQnj6vlCU4S6KoQhq_mgS7A8p-zeSvXcqX4EzX63LCyhyMKEHTToyOZLOjWjDGfKggl3ATa-es-7JMz_UMmS1QdRZpr9RY9j64X_EJ7cANqj1k7YymnJxRuxWIBg1fBysdN-e7Z0IjHaUiMStMo_k-OhU7QA_ke2vYQhx9GlGDM_SN6870Rs6agskfYSw14" />
              </video>
              {/* Top Meta overlay */}
              <div className="relative z-10 p-5 flex items-center justify-between bg-gradient-to-b from-navy-950/80 to-transparent">
                <div className="flex items-center gap-2">
                  <span className="w-2.5 h-2.5 rounded-full bg-solar-500 animate-ping"></span>
                  <span className="text-xs font-bold text-white">AI Vision Stream 04</span>
                </div>
                <span className="text-[10px] font-mono text-slate-300 bg-black/40 px-2 py-0.5 rounded backdrop-blur">FPS: 59.9</span>
              </div>
              {/* Centered Overlay Button: EXACT match to Predict AI glow button in Navbar */}
              <div className="relative z-20 flex flex-col items-center justify-center my-auto p-4 text-center">
                <button className="predict-ai-glow px-7 py-3.5 rounded-full bg-gradient-to-r from-solar-500 to-solar-600 text-white font-bold text-sm border-2 border-solar-400 hover:brightness-110 active:scale-95 shadow-2xl transition-all flex items-center gap-3">
                  <i className="fa-solid fa-chart-line text-base"></i>
                  <span>Demand Forecast</span>
                </button>
                <p className="text-[11px] text-slate-200 mt-2 font-medium drop-shadow">Simulate basket volume for next 72 hours</p>
              </div>
              {/* Bottom bar */}
              <div className="relative z-10 p-4 bg-navy-950/90 backdrop-blur-xs border-t border-white/10 flex items-center justify-between text-xs text-slate-300">
                <span>Model: Transformer-Retail v2</span>
                <span className="text-emerald-400 font-semibold">99.4% Accuracy</span>
              </div>
            </div>
          </div>
          {/* Bottom Container: Counters (25% height) - Full-width horizontal flex row */}
          <div className="mt-6 bg-white rounded-2xl border border-slate-200 shadow-sm p-6 flex flex-wrap md:flex-nowrap justify-around items-center gap-6">
            {/* Block 1 */}
            <div className="flex flex-col items-center text-center px-4 w-full sm:w-1/2 md:w-1/4 border-r last:border-none border-slate-100">
              <div className="w-12 h-12 rounded-2xl bg-orange-50 text-solar-600 flex items-center justify-center text-xl mb-2 shadow-2xs">
                <i className="fa-solid fa-users"></i>
              </div>
              <span className={`counter-number font-mono text-3xl md:text-4xl font-extrabold transition-colors duration-1000 ${activeSection === "predict-ai" ? "text-solar-600" : "text-navy-900"}`}><AnimatedCounter target={88} isActive={activeSection === "predict-ai"} /></span>
              <span className="text-xs font-semibold text-slate-500 mt-1 flex items-center justify-center gap-1.5"><i className="fa-solid fa-users"></i> 124 Visitors Today</span>
            </div>
            {/* Block 2 */}
            <div className="flex flex-col items-center text-center px-4 w-full sm:w-1/2 md:w-1/4 border-r last:border-none border-slate-100">
              <div className="w-12 h-12 rounded-2xl bg-teal-50 text-teal-600 flex items-center justify-center text-xl mb-2 shadow-2xs">
                <i className="fa-solid fa-cart-arrow-down"></i>
              </div>
              <span className={`counter-number font-mono text-3xl md:text-4xl font-extrabold transition-colors duration-1000 ${activeSection === "predict-ai" ? "text-teal-600" : "text-navy-900"}`}><AnimatedCounter target={342} isActive={activeSection === "predict-ai"} /></span>
              <span className="text-xs font-semibold text-slate-500 mt-1 flex items-center justify-center gap-1.5"><i className="fa-solid fa-basket-shopping"></i> Active Smart Baskets</span>
            </div>
            {/* Block 3 */}
            <div className="flex flex-col items-center text-center px-4 w-full sm:w-1/2 md:w-1/4 border-r last:border-none border-slate-100">
              <div className="w-12 h-12 rounded-2xl bg-emerald-50 text-emerald-600 flex items-center justify-center text-xl mb-2 shadow-2xs">
                <i className="fa-solid fa-clock-rotate-left"></i>
              </div>
              <span className={`counter-number font-mono text-3xl md:text-4xl font-extrabold transition-colors duration-1000 ${activeSection === "predict-ai" ? "text-emerald-600" : "text-navy-900"}`}><AnimatedCounter target={96} isActive={activeSection === "predict-ai"} /></span>
              <span className="text-xs font-semibold text-slate-500 mt-1 flex items-center justify-center gap-1.5"><i className="fa-solid fa-stopwatch"></i> Avg Checkout (Sec)</span>
            </div>
            {/* Block 4 */}
            <div className="flex flex-col items-center text-center px-4 w-full sm:w-1/2 md:w-1/4">
              <div className="w-12 h-12 rounded-2xl bg-amber-50 text-amber-600 flex items-center justify-center text-xl mb-2 shadow-2xs">
                <i className="fa-solid fa-sack-dollar"></i>
              </div>
              <span className={`counter-number font-mono text-3xl md:text-4xl font-extrabold transition-colors duration-1000 ${activeSection === "predict-ai" ? "text-amber-600" : "text-navy-900"}`}><AnimatedCounter target={52} isActive={activeSection === "predict-ai"} /></span>
              <span className="text-xs font-semibold text-slate-500 mt-1 flex items-center justify-center gap-1.5"><i className="fa-solid fa-money-bill-wave"></i> Avg Basket Size ($)</span>
            </div>
          </div>
        </section>
        {/* SECTION 5: TROUBLESHOOTING - PANORAMIC BENCH & 4-COLUMN ALERTS GRID (FROM SCREEN_2) */}
        <section className="min-h-[90vh] py-10 px-6 md:px-12 lg:px-16 max-w-[1720px] mx-auto flex flex-col justify-between" id="troubleshooting">
          {/* Stacked Command Center Structure */}
          <div className="space-y-6">
            {/* Command Center Header Banner */}
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-white rounded-2xl border border-slate-200 shadow-sm p-6">
              <div>
                <span className="text-xs font-bold uppercase tracking-wider text-solar-600">Hardware Diagnostic Node</span>
                <h2 className="text-2xl md:text-3xl font-extrabold text-navy-900 tracking-tight">Troubleshooting &amp; Fleet Diagnostics</h2>
                <p className="text-xs md:text-sm text-slate-500 mt-1">Real-time sensor telemetry, weighing load cells, and BLE beacons for Trolley #TR-402.</p>
              </div>
              <div className="flex items-center gap-4 shrink-0">
                <span className="text-xs text-slate-500 flex items-center gap-2">
                  <i className="fa-solid fa-circle-check text-emerald-500"></i>
                  Firmware v4.8.2-stable (Build 2025.11)
                </span>
                <button className="px-4 py-2 rounded-xl bg-solar-50 text-solar-700 border border-solar-200 hover:bg-solar-100 font-semibold text-xs flex items-center gap-1.5 transition-colors">
                  <span>Run Diagnostic Cycle</span>
                  <i className="fa-solid fa-rotate text-xs"></i>
                </button>
              </div>
            </div>
            {/* Central Showcase: Diagnostic Stage with Perimeter Telemetry Readouts */}
            <div className="bg-white rounded-2xl border border-slate-200 shadow-sm p-6 relative overflow-hidden">
              <div className="relative w-full h-[320px] bg-slate-50/80 rounded-xl border border-slate-200/80 flex items-center justify-center overflow-hidden group">
                {/* Abstract Grid Coordinate Floor (3D model staging) */}
                <div className="absolute inset-0 bg-[radial-gradient(#CBD5E1_1px,transparent_1px)] [background-size:16px_16px] opacity-40"></div>
                {/* Central Shopping Cart Graphic */}
                <div className="relative z-10 w-full h-full flex flex-col items-center justify-center">
                  <div className="w-full h-full absolute inset-0 cursor-move">
                    <Canvas camera={{ position: [0, 2, 5], fov: 45 }}>
                      <Suspense fallback={<Loader />}>
                        <ambientLight intensity={0.5} />
                        <directionalLight position={[10, 10, 5]} intensity={1} castShadow />
                        <Stage environment={null} intensity={0.6}>
                          <CartModel />
                        </Stage>
                      </Suspense>
                      <OrbitControls autoRotate enableZoom={false} />
                    </Canvas>
                  </div>
                  <div className="absolute bottom-4 left-1/2 -translate-x-1/2 text-center pointer-events-none">
                    <span className="inline-flex items-center gap-1.5 px-3 py-0.5 rounded-full bg-navy-900/90 backdrop-blur-sm text-white font-mono text-[11px] shadow-sm">
                      <i className="fa-solid fa-cube text-solar-400"></i>
                      <span>WebGL Three.js Engine Active</span>
                    </span>
                    <p className="text-[11px] text-slate-500 mt-1 font-mono bg-white/50 px-2 py-0.5 rounded">Pitch: 0.0° · Yaw: 45.2° · Roll: 0.0° · Sensor Fusion: Online</p>
                  </div>
                </div>
                {/* Perimeter Telemetry Readout Pins */}
                <div className="absolute top-4 left-4 bg-white/95 backdrop-blur-xs p-2.5 rounded-xl border border-slate-200 shadow-sm text-xs">
                  <span className="text-slate-400 text-[10px] uppercase font-bold block">Left Scale Load Cell</span>
                  <span className="font-mono font-bold text-navy-900">4.120 kg ± 0.005</span>
                </div>
                <div className="absolute top-4 right-4 bg-white/95 backdrop-blur-xs p-2.5 rounded-xl border border-slate-200 shadow-sm text-xs text-right">
                  <span className="text-slate-400 text-[10px] uppercase font-bold block">Fleet Health</span>
                  <span className="font-mono font-bold text-emerald-600">97.8% (42 Active Units)</span>
                </div>
                <div className="absolute bottom-4 right-4 bg-white/95 backdrop-blur-xs p-2.5 rounded-xl border border-slate-200 shadow-sm text-xs">
                  <span className="text-slate-400 text-[10px] uppercase font-bold block">Lithium Battery Pack</span>
                  <span className="font-mono font-bold text-emerald-600 flex items-center gap-1.5">
                    <i className="fa-solid fa-battery-three-quarters text-emerald-500"></i> 84% (16.4 Hrs Rem.)
                  </span>
                </div>
                <div className="absolute bottom-4 left-4 bg-white/95 backdrop-blur-xs p-2.5 rounded-xl border border-slate-200 shadow-sm text-xs">
                  <span className="text-slate-400 text-[10px] uppercase font-bold block">LiDAR Range</span>
                  <span className="font-mono font-bold text-navy-900">0.05m - 12.00m active</span>
                </div>
              </div>
            </div>
            {/* Horizontal Split Alerts Feed */}
            <div className="bg-white rounded-2xl border border-slate-200 shadow-sm p-6">
              <div className="flex items-center justify-between pb-4 border-b border-slate-100 shrink-0">
                <div className="flex items-center gap-2">
                  <h3 className="text-lg font-bold text-navy-900">Alerts</h3>
                  <span className="bg-solar-50 text-solar-700 font-mono text-[11px] font-bold px-2 py-0.5 rounded-full border border-solar-200">3 New</span>
                </div>
                {/* "Add Cart" outline button */}
                <button className="px-3 py-1.5 rounded-lg border border-slate-300 hover:border-navy-800 text-navy-900 font-semibold text-xs transition-colors flex items-center gap-1.5 hover:bg-slate-50">
                  <i className="fa-solid fa-plus text-[10px]"></i>
                  <span>Add Cart</span>
                </button>
              </div>
              {/* Horizontal Split Grid of Alert Items */}
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mt-4">
                {/* Alert Item 1: Error */}
                <div className="p-3.5 rounded-xl bg-red-50/80 border border-red-200 text-xs flex flex-col justify-between">
                  <div>
                    <div className="flex items-start justify-between">
                      <span className="font-bold text-red-700 flex items-center gap-1.5">
                        <i className="fa-solid fa-triangle-exclamation"></i>
                        <span>Trolley #TR-108</span>
                      </span>
                      <span className="text-[10px] text-red-500 font-mono">2m ago</span>
                    </div>
                    <p className="text-slate-700 font-medium mt-1">Weight discrepancy detected. Barcode item scanned without basket mass change.</p>
                  </div>
                  <div className="mt-3 pt-2 border-t border-red-200/50 flex items-center justify-between text-[11px]">
                    <span className="text-red-600 font-semibold">Load Sensor Discrepancy</span>
                    <button className="text-navy-900 underline font-semibold hover:text-solar-600">Inspect</button>
                  </div>
                </div>
                {/* Alert Item 2: Battery Info */}
                <div className="p-3.5 rounded-xl bg-amber-50/80 border border-amber-200 text-xs flex flex-col justify-between">
                  <div>
                    <div className="flex items-start justify-between">
                      <span className="font-bold text-amber-800 flex items-center gap-1.5">
                        <i className="fa-solid fa-battery-quarter"></i>
                        <span>Trolley #TR-042</span>
                      </span>
                      <span className="text-[10px] text-amber-600 font-mono">14m ago</span>
                    </div>
                    <p className="text-slate-700 font-medium mt-1">Battery low (&lt;12%). Guided self-docking initiated to charging bay 3.</p>
                  </div>
                  <div className="mt-3 pt-2 border-t border-amber-200/50 flex items-center justify-between text-[11px]">
                    <span className="text-amber-700 font-semibold">Auto-Docking</span>
                    <button className="text-navy-900 underline font-semibold hover:text-solar-600">Reroute</button>
                  </div>
                </div>
                {/* Alert Item 3: Geofence Jump */}
                <div className="p-3.5 rounded-xl bg-orange-50/80 border border-orange-200 text-xs flex flex-col justify-between">
                  <div>
                    <div className="flex items-start justify-between">
                      <span className="font-bold text-solar-700 flex items-center gap-1.5">
                        <i className="fa-solid fa-map-pin"></i>
                        <span>Trolley #TR-319</span>
                      </span>
                      <span className="text-[10px] text-solar-600 font-mono">28m ago</span>
                    </div>
                    <p className="text-slate-700 font-medium mt-1">Geofence boundary breach at parking lot perimeter. Wheels locked safely.</p>
                  </div>
                  <div className="mt-3 pt-2 border-t border-orange-200/50 flex items-center justify-between text-[11px]">
                    <span className="text-solar-800 font-semibold">Wheel-Lock Active</span>
                    <button className="text-navy-900 underline font-semibold hover:text-solar-600">Unlock</button>
                  </div>
                </div>
                {/* Alert Item 4: Scheduled Maintenance */}
                <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 text-xs flex flex-col justify-between">
                  <div>
                    <div className="flex items-start justify-between">
                      <span className="font-bold text-slate-700 flex items-center gap-1.5">
                        <i className="fa-solid fa-wrench"></i>
                        <span>Trolley #TR-214</span>
                      </span>
                      <span className="text-[10px] text-slate-400 font-mono">1h ago</span>
                    </div>
                    <p className="text-slate-600 font-medium mt-1">100-hour camera optical lens recalibration due.</p>
                  </div>
                  <div className="mt-3 pt-2 border-t border-slate-200/50 flex items-center justify-between text-[11px]">
                    <span className="text-slate-500 font-semibold">Maintenance Due</span>
                    <button className="text-navy-900 underline font-semibold hover:text-solar-600">Schedule</button>
                  </div>
                </div>
              </div>
            </div>
          </div>
          {/* Bottom Carousel Area (20% height): Infinite Auto-scrolling Marquee */}
          <div className="mt-6 bg-navy-900 rounded-2xl border border-navy-800 shadow-md p-4 overflow-hidden relative flex items-center">
            {/* Marquee Label Badge */}
            <div className="absolute left-4 z-20 bg-navy-950/90 backdrop-blur px-3 py-1.5 rounded-lg border border-navy-700 text-xs font-bold text-solar-400 flex items-center gap-2 shadow-md">
              <i className="fa-solid fa-fire"></i>
              <span>Top-Selling Brand Partners</span>
            </div>
            {/* Left / Right Vignette Shadows for Seamless Blend */}
            <div className="absolute left-0 top-0 bottom-0 w-36 bg-gradient-to-r from-navy-900 to-transparent z-10 pointer-events-none"></div>
            <div className="absolute right-0 top-0 bottom-0 w-36 bg-gradient-to-l from-navy-900 to-transparent z-10 pointer-events-none"></div>
            {/* Infinite Scrolling Marquee Track */}
            <div className="marquee-track flex items-center gap-12 pl-64 select-none">
              {/* Item 1 */}
              <div className="flex items-center gap-3 bg-navy-800/80 px-4 py-2 rounded-xl border border-navy-700/60 shrink-0">
                <i className="fa-solid fa-bottle-water text-cyan-400 text-lg"></i>
                <div>
                  <span className="text-xs font-bold text-white block">AquaPure Spring</span>
                  <span className="text-[10px] text-slate-400">1,420 units/day</span>
                </div>
              </div>
              {/* Item 2 */}
              <div className="flex items-center gap-3 bg-navy-800/80 px-4 py-2 rounded-xl border border-navy-700/60 shrink-0">
                <i className="fa-solid fa-mug-hot text-amber-400 text-lg"></i>
                <div>
                  <span className="text-xs font-bold text-white block">RoastMaster Espresso</span>
                  <span className="text-[10px] text-slate-400">980 units/day</span>
                </div>
              </div>
              {/* Item 3 */}
              <div className="flex items-center gap-3 bg-navy-800/80 px-4 py-2 rounded-xl border border-navy-700/60 shrink-0">
                <i className="fa-solid fa-cookie-bite text-orange-400 text-lg"></i>
                <div>
                  <span className="text-xs font-bold text-white block">CrunchBites Oats</span>
                  <span className="text-[10px] text-slate-400">840 units/day</span>
                </div>
              </div>
              {/* Item 4 */}
              <div className="flex items-center gap-3 bg-navy-800/80 px-4 py-2 rounded-xl border border-navy-700/60 shrink-0">
                <i className="fa-solid fa-ice-cream text-pink-400 text-lg"></i>
                <div>
                  <span className="text-xs font-bold text-white block">Alpine Creamery</span>
                  <span className="text-[10px] text-slate-400">760 units/day</span>
                </div>
              </div>
              {/* Item 5 */}
              <div className="flex items-center gap-3 bg-navy-800/80 px-4 py-2 rounded-xl border border-navy-700/60 shrink-0">
                <i className="fa-solid fa-apple-whole text-emerald-400 text-lg"></i>
                <div>
                  <span className="text-xs font-bold text-white block">GreenValley Orchard</span>
                  <span className="text-[10px] text-slate-400">1,120 units/day</span>
                </div>
              </div>
              {/* Item 6 */}
              <div className="flex items-center gap-3 bg-navy-800/80 px-4 py-2 rounded-xl border border-navy-700/60 shrink-0">
                <i className="fa-solid fa-bread-slice text-yellow-400 text-lg"></i>
                <div>
                  <span className="text-xs font-bold text-white block">GoldenCrust Bakery</span>
                  <span className="text-[10px] text-slate-400">650 units/day</span>
                </div>
              </div>
              {/* Duplicate Set for Seamless Loop */}
              <div className="flex items-center gap-3 bg-navy-800/80 px-4 py-2 rounded-xl border border-navy-700/60 shrink-0">
                <i className="fa-solid fa-bottle-water text-cyan-400 text-lg"></i>
                <div>
                  <span className="text-xs font-bold text-white block">AquaPure Spring</span>
                  <span className="text-[10px] text-slate-400">1,420 units/day</span>
                </div>
              </div>
              <div className="flex items-center gap-3 bg-navy-800/80 px-4 py-2 rounded-xl border border-navy-700/60 shrink-0">
                <i className="fa-solid fa-mug-hot text-amber-400 text-lg"></i>
                <div>
                  <span className="text-xs font-bold text-white block">RoastMaster Espresso</span>
                  <span className="text-[10px] text-slate-400">980 units/day</span>
                </div>
              </div>
              <div className="flex items-center gap-3 bg-navy-800/80 px-4 py-2 rounded-xl border border-navy-700/60 shrink-0">
                <i className="fa-solid fa-cookie-bite text-orange-400 text-lg"></i>
                <div>
                  <span className="text-xs font-bold text-white block">CrunchBites Oats</span>
                  <span className="text-[10px] text-slate-400">840 units/day</span>
                </div>
              </div>
              <div className="flex items-center gap-3 bg-navy-800/80 px-4 py-2 rounded-xl border border-navy-700/60 shrink-0">
                <i className="fa-solid fa-ice-cream text-pink-400 text-lg"></i>
                <div>
                  <span className="text-xs font-bold text-white block">Alpine Creamery</span>
                  <span className="text-[10px] text-slate-400">760 units/day</span>
                </div>
              </div>
            </div>
          </div>
        </section>
      </main>
      {/* ========================================================================= */}
      {/* JAVASCRIPT: Scroll Telemetry, Dynamic Navbar Morph, Counters, Graph Draw */}
      {/* ========================================================================= */}
    </>
  );
}
