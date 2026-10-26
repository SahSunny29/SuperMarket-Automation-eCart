import re

# ------------- dashboard/page.tsx edits -------------
dashboard_path = "c:/Users/Sunny Kumar Sah/OneDrive/Study Materials/Projects/ECS/Ver 1.0/Frontend/smart-trolley/src/app/dashboard/page.tsx"
with open(dashboard_path, "r", encoding="utf-8") as f:
    dashboard_content = f.read()

# Smoothen navbar
dashboard_content = dashboard_content.replace(
    'transition-all duration-500 ease-in-out pointer-events-none ${scrolled',
    'transition-all duration-700 ease-[cubic-bezier(0.25,1,0.5,1)] pointer-events-none ${scrolled'
)
dashboard_content = dashboard_content.replace(
    'transition-all duration-500 ease-in-out ${scrolled',
    'transition-all duration-700 ease-[cubic-bezier(0.25,1,0.5,1)] ${scrolled'
)

# Hide company name on small state
dashboard_content = dashboard_content.replace(
    '<div className="flex flex-col">\n<span className="font-extrabold',
    '<div className={`flex-col ${scrolled ? "hidden" : "flex"}`}>\n<span className="font-extrabold'
)

# Ensure button text size is not reduced (Upgrade to text-sm)
dashboard_content = dashboard_content.replace(
    'nav-item text-xs font-semibold px-4 py-2',
    'nav-item text-sm font-semibold px-4 py-2'
)

# Fix interactive toggle logic
dashboard_content = dashboard_content.replace(
    '<span className="text-[11px] font-bold text-emerald-700 uppercase tracking-wider" id="store-status-text">Open</span>',
    '<span className={`text-[11px] font-bold uppercase tracking-wider ${isStoreOpen ? "text-emerald-700" : "text-slate-500"}`} id="store-status-text">{isStoreOpen ? "Open" : "Closed"}</span>'
)
dashboard_content = dashboard_content.replace(
    '<button className="w-12 h-6 rounded-full bg-emerald-500 p-0.5 transition-colors duration-300 relative focus:outline-none shadow-inner" id="store-toggle-btn" onClick={() => {}}>',
    '<button className={`w-12 h-6 rounded-full p-0.5 transition-colors duration-300 relative focus:outline-none shadow-inner ${isStoreOpen ? "bg-emerald-500" : "bg-slate-300"}`} id="store-toggle-btn" onClick={() => setIsStoreOpen(!isStoreOpen)}>'
)
dashboard_content = dashboard_content.replace(
    '<div className="w-5 h-5 rounded-full bg-white shadow-md transform translate-x-6 transition-transform duration-300" id="toggle-knob"></div>',
    '<div className={`w-5 h-5 rounded-full bg-white shadow-md transform transition-transform duration-300 ${isStoreOpen ? "translate-x-6" : "translate-x-0"}`} id="toggle-knob"></div>'
)

# Replace Hero Video
dashboard_content = dashboard_content.replace(
    '<source src="https://assets.mixkit.co/videos/preview/mixkit-supermarket-aisle-with-lots-of-merchandise-41315-large.mp4" type="video/mp4"/>',
    '<source src="/Hero.mp4" type="video/mp4"/>'
)

with open(dashboard_path, "w", encoding="utf-8") as f:
    f.write(dashboard_content)


# ------------- login/page.tsx edits -------------
login_path = "c:/Users/Sunny Kumar Sah/OneDrive/Study Materials/Projects/ECS/Ver 1.0/Frontend/smart-trolley/src/app/login/page.tsx"
with open(login_path, "r", encoding="utf-8") as f:
    login_content = f.read()

# Replace Login Video
login_content = login_content.replace(
    '<source src="https://assets.mixkit.co/videos/preview/mixkit-supermarket-aisle-view-from-a-shopping-cart-42861-large.mp4" type="video/mp4" />',
    '<source src="/Login.mp4" type="video/mp4" />'
)

with open(login_path, "w", encoding="utf-8") as f:
    f.write(login_content)

print("UI fixes and media replacements applied successfully.")
