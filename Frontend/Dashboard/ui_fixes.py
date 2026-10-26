import re

file_path = "c:/Users/Sunny Kumar Sah/OneDrive/Study Materials/Projects/ECS/Ver 1.0/Frontend/smart-trolley/src/app/dashboard/page.tsx"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Task 2
content = content.replace(
    '<section className="min-h-[90vh] py-10 px-6 md:px-12 lg:px-16 max-w-[1720px] mx-auto flex flex-col justify-center relative" id="store-map">',
    '<section className="min-h-[90vh] py-10 px-6 md:px-12 lg:px-16 max-w-[1720px] mx-auto flex flex-col justify-center relative bg-navy-950" id="store-map" style={{ backgroundImage: `url(${storeMapBg.src})`, backgroundSize: \'cover\', backgroundPosition: \'center\' }}>'
)

# Task 3
content = content.replace(
    '<img alt="Supermarket Aisle" className="w-full h-full object-cover filter brightness-[0.35] contrast-105 scale-105 transition-transform duration-1000 ease-out hover:scale-100" src="https://lh3.googleusercontent.com/aida-public/AB6AXuCcbbLsUryCYf51IHFrOLN6esG93Cf_Zkj6H0VBxBYipMch95j7nGUqljJRpLveOBxxZc55cVXO61AVdIxRhzCh7zUcf0xEluSQbnFa7B1JIbMGqf9FKu8cKhyDAHPWqgqjbtKYgCUQ4T8VLRCmB_eTyLR336mCjNd9Fj0OTUv_vewVj-DY1CS4OvufdDPSaI28inbDvucPMlkqcM0dSg2Ne2G-EFpHmnks9WUP8y3pdtlgtYhszLhh"/>',
    '<img alt="Supermarket Aisle" className="w-full h-full object-cover filter brightness-[0.35] contrast-105 scale-105 transition-transform duration-1000 ease-out hover:scale-100" src={storeSettingsBg.src} />'
)

# Task 4
content = content.replace(
    '<div className="flex items-center gap-3">\n<div className="w-10 h-10 rounded-xl bg-orange-50 text-solar-600 flex items-center justify-center font-bold text-lg">\n<i className="fa-solid fa-boxes-stacked"></i>\n</div>\n<div>\n<span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Aisle Node 01</span>\n<h3 className="text-base font-extrabold text-navy-900">Inventory</h3>\n</div>\n</div>',
    '<div className="flex flex-col items-center gap-3 text-center">\n<div className="w-12 h-12 rounded-xl bg-orange-50 text-solar-600 flex items-center justify-center font-bold text-xl">\n<i className="fa-solid fa-boxes-stacked"></i>\n</div>\n<div className="flex flex-col items-center">\n<span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Aisle Node 01</span>\n<h3 className="text-base font-extrabold text-navy-900">Inventory</h3>\n</div>\n</div>'
)
content = content.replace(
    '<p className="text-xs text-slate-600 mt-3 line-clamp-2">\n              Automated tare-weight calibration and shelf restock trigger threshold controls.\n            </p>',
    '<p className="text-xs text-slate-600 mt-3 line-clamp-2 text-center">\n              Automated tare-weight calibration and shelf restock trigger threshold controls.\n            </p>'
)
content = content.replace('<span className="text-slate-500">Auto-Refill Threshold:</span>', '<span className="text-slate-500 flex items-center gap-1.5"><i className="fa-solid fa-chart-pie"></i> Auto-Refill:</span>')
content = content.replace('<span className="text-slate-500">Tare Calibration:</span>', '<span className="text-slate-500 flex items-center gap-1.5"><i className="fa-solid fa-scale-balanced"></i> Tare Calibration:</span>')


content = content.replace(
    '<div className="flex items-center gap-3">\n<div className="w-10 h-10 rounded-xl bg-teal-50 text-teal-600 flex items-center justify-center font-bold text-lg">\n<i className="fa-solid fa-sliders"></i>\n</div>\n<div>\n<span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Core Firmware</span>\n<h3 className="text-base font-extrabold text-navy-900">System Settings</h3>\n</div>\n</div>',
    '<div className="flex flex-col items-center gap-3 text-center">\n<div className="w-12 h-12 rounded-xl bg-teal-50 text-teal-600 flex items-center justify-center font-bold text-xl">\n<i className="fa-solid fa-sliders"></i>\n</div>\n<div className="flex flex-col items-center">\n<span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Core Firmware</span>\n<h3 className="text-base font-extrabold text-navy-900">System Settings</h3>\n</div>\n</div>'
)
content = content.replace(
    '<p className="text-xs text-slate-600 mt-3 line-clamp-2">\n              Optical barcode scan intervals, LiDAR perimeter guard, and emergency brake override.\n            </p>',
    '<p className="text-xs text-slate-600 mt-3 line-clamp-2 text-center">\n              Optical barcode scan intervals, LiDAR perimeter guard, and emergency brake override.\n            </p>'
)
content = content.replace('<span className="text-slate-500">Scan Frequency:</span>', '<span className="text-slate-500 flex items-center gap-1.5"><i className="fa-solid fa-gauge-high"></i> Scan Frequency:</span>')
content = content.replace('<span className="text-slate-500">Geofence Guard:</span>', '<span className="text-slate-500 flex items-center gap-1.5"><i className="fa-solid fa-shield-halved"></i> Geofence Guard:</span>')


content = content.replace(
    '<div className="flex items-center gap-3">\n<div className="w-10 h-10 rounded-xl bg-purple-50 text-purple-600 flex items-center justify-center font-bold text-lg">\n<i className="fa-solid fa-users-gear"></i>\n</div>\n<div>\n<span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Duty Roster</span>\n<h3 className="text-base font-extrabold text-navy-900">Staff Info</h3>\n</div>\n</div>',
    '<div className="flex flex-col items-center gap-3 text-center">\n<div className="w-12 h-12 rounded-xl bg-purple-50 text-purple-600 flex items-center justify-center font-bold text-xl">\n<i className="fa-solid fa-users-gear"></i>\n</div>\n<div className="flex flex-col items-center">\n<span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Duty Roster</span>\n<h3 className="text-base font-extrabold text-navy-900">Staff Info</h3>\n</div>\n</div>'
)
content = content.replace(
    '<p className="text-xs text-slate-600 mt-3 line-clamp-2">\n              Floor assistance dispatch, technician on-call routing, and supervisory override badges.\n            </p>',
    '<p className="text-xs text-slate-600 mt-3 line-clamp-2 text-center">\n              Floor assistance dispatch, technician on-call routing, and supervisory override badges.\n            </p>'
)
content = content.replace('<span className="text-slate-500">Active Supervisors:</span>', '<span className="text-slate-500 flex items-center gap-1.5"><i className="fa-solid fa-user-tie"></i> Supervisors:</span>')
content = content.replace('<span className="text-slate-500">Avg Incident Response:</span>', '<span className="text-slate-500 flex items-center gap-1.5"><i className="fa-solid fa-stopwatch"></i> Incident Response:</span>')

# Task 5
content = content.replace(
    '<span className="counter-number font-mono text-3xl md:text-4xl font-extrabold text-navy-900" data-target="88">0</span>',
    '<span className={`counter-number font-mono text-3xl md:text-4xl font-extrabold transition-colors duration-1000 ${activeSection === "predict-ai" ? "text-solar-600" : "text-navy-900"}`}><AnimatedCounter target={88} isActive={activeSection === "predict-ai"} /></span>'
)
content = content.replace(
    '<span className="counter-number font-mono text-3xl md:text-4xl font-extrabold text-navy-900" data-target="342">0</span>',
    '<span className={`counter-number font-mono text-3xl md:text-4xl font-extrabold transition-colors duration-1000 ${activeSection === "predict-ai" ? "text-teal-600" : "text-navy-900"}`}><AnimatedCounter target={342} isActive={activeSection === "predict-ai"} /></span>'
)
content = content.replace(
    '<span className="counter-number font-mono text-3xl md:text-4xl font-extrabold text-navy-900" data-target="96">0</span>',
    '<span className={`counter-number font-mono text-3xl md:text-4xl font-extrabold transition-colors duration-1000 ${activeSection === "predict-ai" ? "text-emerald-600" : "text-navy-900"}`}><AnimatedCounter target={96} isActive={activeSection === "predict-ai"} /></span>'
)
content = content.replace(
    '<span className="counter-number font-mono text-3xl md:text-4xl font-extrabold text-navy-900" data-target="52">0</span>',
    '<span className={`counter-number font-mono text-3xl md:text-4xl font-extrabold transition-colors duration-1000 ${activeSection === "predict-ai" ? "text-amber-600" : "text-navy-900"}`}><AnimatedCounter target={52} isActive={activeSection === "predict-ai"} /></span>'
)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Tasks 2,3,4,5 modifications written to file.")
