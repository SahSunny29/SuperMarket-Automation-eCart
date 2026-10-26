import re

def convert_html_to_jsx(html_path, out_path):
    with open(html_path, 'r', encoding='utf-8') as f:
        html = f.read()

    html = re.sub(r'<!--(.*?)-->', r'{/*\1*/}', html, flags=re.DOTALL)
    html = re.sub(r'\bclass=', 'className=', html)
    html = re.sub(r'\bfor=', 'htmlFor=', html)
    html = re.sub(r'\bonclick="[^"]*"', 'onClick={() => {}}', html)
    html = re.sub(r'\bautoplay(="")?', 'autoPlay', html)
    html = re.sub(r'\bplaysinline(="")?', 'playsInline', html)
    html = re.sub(r'\bmuted(="")?', 'muted', html)
    html = re.sub(r'\bloop(="")?', 'loop', html)
    html = re.sub(r'\bstroke-width=', 'strokeWidth=', html)
    html = re.sub(r'\bstroke-linecap=', 'strokeLinecap=', html)
    html = re.sub(r'\bstroke-linejoin=', 'strokeLinejoin=', html)
    html = re.sub(r'\bstroke-dasharray=', 'strokeDasharray=', html)
    html = re.sub(r'\bstroke-dashoffset=', 'strokeDashoffset=', html)
    html = re.sub(r'\bpatternunits=', 'patternUnits=', html)
    html = re.sub(r'\bpreserveaspectratio=', 'preserveAspectRatio=', html)
    html = re.sub(r'\bviewbox=', 'viewBox=', html)
    html = re.sub(r'<lineargradient\b', '<linearGradient', html)
    html = re.sub(r'</lineargradient>', '</linearGradient>', html)

    # Self closing tags
    for tag in ['img', 'input', 'br', 'hr', 'source']:
        # This naive regex finds e.g. <img ... > without a closing slash and adds it
        # Doesn't handle > inside strings but should work for most HTML
        html = re.sub(rf'<{tag}([^>]*?)(?<!/)>', rf'<{tag}\1 />', html)

    # Wrap in a component
    jsx = f"""\"use client\";
import React, {{ useEffect }} from 'react';

export default function Dashboard() {{
  useEffect(() => {{
    // Animations or scripts can be added here
  }}, []);

  return (
    <>
      {{/* Extracted Dashboard Content */}}
      {html}
    </>
  );
}}
"""

    with open(out_path, 'w', encoding='utf-8') as f:
        f.write(jsx)

if __name__ == '__main__':
    convert_html_to_jsx('src/app/dashboard/dashboard.html', 'src/app/dashboard/page.tsx')
