import re

file_path = "c:/Users/Sunny Kumar Sah/OneDrive/Study Materials/Projects/ECS/Ver 1.0/Frontend/smart-trolley/src/app/dashboard/page.tsx"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Navbar Container
content = content.replace(
    'className="fixed top-0 left-0 right-0 z-50 flex justify-center px-0 transition-all duration-300 pointer-events-none" id="main-navbar-container"',
    'className={`fixed top-0 left-0 right-0 z-50 flex justify-center transition-all duration-300 pointer-events-none ${scrolled ? "px-4 sm:px-8 pt-3" : "px-0"}`} id="main-navbar-container"'
)

# 2. Navbar
content = content.replace(
    'className="pointer-events-auto w-full h-[10vh] max-h-[88px] min-h-[64px] bg-white/95 backdrop-blur-md border-b border-slate-200/90 shadow-sm px-6 md:px-10 flex items-center justify-between transition-all duration-300" id="main-navbar"',
    'className={`pointer-events-auto min-h-[64px] backdrop-blur-md border-slate-200/90 px-6 md:px-10 flex items-center justify-between transition-all duration-300 ${scrolled ? "max-w-6xl h-14 rounded-full border shadow-lg bg-white/90" : "w-full h-[10vh] max-h-[88px] rounded-none border-b bg-white/95 shadow-sm"}`} id="main-navbar"'
)

# 3. Scroll Progress Track
content = content.replace(
    'className="absolute top-2 right-[9px] w-[2px] bg-solar-500 transition-all duration-150 h-0" id="scroll-track-progress"',
    'className="absolute top-2 right-[9px] w-[2px] bg-solar-500 transition-all duration-150" style={{ height: `${scrollPercent}%` }} id="scroll-track-progress"'
)

# 4. Scroll Guide Nodes
sections = ['about-us', 'store-map', 'store-settings', 'predict-ai', 'troubleshooting']

for idx, sec in enumerate(sections):
    pattern = r'(<a[^>]*data-section="' + sec + r'"[^>]*>.*?)(<span className="node-label[^"]*")(>.*?</span>.*?)(<div className="node-dot[^"]*")(></div>.*?</a>)'
    
    def repl(m):
        target_label_class = f'<span className={{`node-label text-xs transition-colors bg-white/90 backdrop-blur-xs px-2 py-0.5 rounded shadow-2xs border border-slate-200/50 ${{activeSection === "{sec}" ? "text-solar-600 font-bold" : "font-semibold text-slate-400 group-hover:text-solar-600"}}`}}'
        
        target_dot_class = f'<div className={{`node-dot w-5 h-5 rounded-full border-2 transition-all duration-300 ${{activeSection === "{sec}" ? "border-solar-500 bg-solar-500 ring-4 ring-orange-100" : "border-slate-300 bg-white ring-0"}}`}}'
        
        return m.group(1) + target_label_class + m.group(3) + target_dot_class + m.group(5)

    content = re.sub(pattern, repl, content, flags=re.DOTALL)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Animations wired up successfully!")
