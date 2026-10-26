import re

file_path = "c:/Users/Sunny Kumar Sah/OneDrive/Study Materials/Projects/ECS/Ver 1.0/Frontend/smart-trolley/src/app/dashboard/page.tsx"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Task 1: Universal Scroll Guide text blend mode
# Original: bg-white/90 backdrop-blur-xs px-2 py-0.5 rounded shadow-2xs border border-slate-200/50 ${activeSection === "..." ? "text-solar-600 font-bold" : "font-semibold text-slate-400 group-hover:text-solar-600"}
# Replacement: mix-blend-difference px-2 py-0.5 rounded ${activeSection === "..." ? "text-solar-400 font-bold" : "font-semibold text-white/90 group-hover:text-solar-400"}
def replace_scroll_guide(m):
    sec = m.group(1)
    return f'<span className={{`node-label text-xs transition-colors mix-blend-difference px-2 py-0.5 rounded ${{activeSection === "{sec}" ? "text-solar-400 font-bold" : "font-semibold text-white/90 group-hover:text-solar-400"}}`}}'

content = re.sub(r'<span className=\{`node-label text-xs transition-colors bg-white/90 backdrop-blur-xs px-2 py-0.5 rounded shadow-2xs border border-slate-200/50 \$\{activeSection === "([^"]+)" \? "text-solar-600 font-bold" : "font-semibold text-slate-400 group-hover:text-solar-600"\}`\}', replace_scroll_guide, content)

# Task 3: Counter text icons
content = content.replace(
    '<span className="text-xs font-semibold text-slate-500 mt-1">124 Visitors Today</span>',
    '<span className="text-xs font-semibold text-slate-500 mt-1 flex items-center justify-center gap-1.5"><i className="fa-solid fa-users"></i> 124 Visitors Today</span>'
)
content = content.replace(
    '<span className="text-xs font-semibold text-slate-500 mt-1">Active Smart Baskets</span>',
    '<span className="text-xs font-semibold text-slate-500 mt-1 flex items-center justify-center gap-1.5"><i className="fa-solid fa-basket-shopping"></i> Active Smart Baskets</span>'
)
content = content.replace(
    '<span className="text-xs font-semibold text-slate-500 mt-1">Avg Checkout (Sec)</span>',
    '<span className="text-xs font-semibold text-slate-500 mt-1 flex items-center justify-center gap-1.5"><i className="fa-solid fa-stopwatch"></i> Avg Checkout (Sec)</span>'
)
content = content.replace(
    '<span className="text-xs font-semibold text-slate-500 mt-1">Avg Basket Size ($)</span>',
    '<span className="text-xs font-semibold text-slate-500 mt-1 flex items-center justify-center gap-1.5"><i className="fa-solid fa-money-bill-wave"></i> Avg Basket Size ($)</span>'
)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Tasks 1 & 3 modifications written to file.")
