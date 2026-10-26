import os
import re

directories_to_scan = [
    "c:/Users/Sunny Kumar Sah/OneDrive/Study Materials/Projects/ECS/Ver 1.0/Frontend/smart-trolley/src/app"
]

replacements = {
    r'\bstop-color=': 'stopColor=',
    r'\bstop-opacity=': 'stopOpacity=',
    r'\bfont-family=': 'fontFamily=',
    r'\bfont-size=': 'fontSize=',
    r'\bfont-weight=': 'fontWeight=',
    r'\btext-anchor=': 'textAnchor='
}

for d in directories_to_scan:
    for root, _, files in os.walk(d):
        for f in files:
            if f.endswith('.tsx') or f.endswith('.jsx'):
                path = os.path.join(root, f)
                with open(path, 'r', encoding='utf-8') as file:
                    content = file.read()
                
                original_content = content
                for k, v in replacements.items():
                    content = re.sub(k, v, content)
                
                if content != original_content:
                    with open(path, 'w', encoding='utf-8') as file:
                        file.write(content)
                    print(f"Updated {path}")
print("Done!")
