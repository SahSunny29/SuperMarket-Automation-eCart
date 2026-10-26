import re

dashboard_path = "c:/Users/Sunny Kumar Sah/OneDrive/Study Materials/Projects/ECS/Ver 1.0/Frontend/smart-trolley/src/app/dashboard/page.tsx"
with open(dashboard_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Navbar transition (duration-300 ease-in)
content = content.replace(
    'transition-all duration-700 ease-[cubic-bezier(0.25,1,0.5,1)] pointer-events-none ${scrolled',
    'transition-all duration-300 ease-in pointer-events-none ${scrolled'
)
content = content.replace(
    'transition-all duration-700 ease-[cubic-bezier(0.25,1,0.5,1)] ${scrolled',
    'transition-all duration-300 ease-in ${scrolled'
)

# 2. Fix useProgress error
loader_old = """const Loader = () => {
  const { progress } = useProgress();
  return <Html center><div className="text-xs font-mono text-slate-500 whitespace-nowrap bg-white/90 backdrop-blur-sm px-4 py-2 rounded-xl shadow-md border border-slate-200/50">Loading WebGL Engine... {progress.toFixed(0)}%</div></Html>;
};"""

loader_new = """const Loader = () => {
  return <Html center><div className="text-xs font-mono text-slate-500 whitespace-nowrap bg-white/90 backdrop-blur-sm px-4 py-2 rounded-xl shadow-md border border-slate-200/50">Loading WebGL Engine...</div></Html>;
};"""

content = content.replace(loader_old, loader_new)

# 3. Hero video fog reduction
content = content.replace(
    'className="absolute inset-0 w-full h-full object-cover opacity-45 pointer-events-none filter brightness-90"',
    'className="absolute inset-0 w-full h-full object-cover pointer-events-none opacity-80"'
)
content = content.replace(
    '<div className="absolute inset-0 bg-gradient-to-t from-navy-950 via-navy-950/60 to-transparent pointer-events-none"></div>\n<div className="absolute inset-0 bg-radial from-transparent via-navy-950/40 to-navy-950/80 pointer-events-none"></div>',
    '<div className="absolute inset-0 bg-gradient-to-t from-navy-950/80 via-navy-950/30 to-transparent pointer-events-none"></div>'
)

# 4. Hero text replacement
content = re.sub(
    r'<h1 className="text-4xl sm:text-5xl md:text-6xl font-extrabold text-white tracking-tight leading-tight drop-shadow-md">\s*About us Section\s*</h1>\s*<p className="mt-4 text-lg md:text-xl font-medium text-slate-300 drop-shadow">\s*Background video will be playing\s*</p>',
    '<h1 className="text-4xl sm:text-5xl md:text-6xl font-extrabold text-white tracking-tight leading-tight drop-shadow-lg">Smart Trolley Enterprise</h1>',
    content
)

with open(dashboard_path, "w", encoding="utf-8") as f:
    f.write(content)

print("UI and bug fixes applied successfully.")
