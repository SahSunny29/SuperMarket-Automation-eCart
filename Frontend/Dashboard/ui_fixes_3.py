import re

file_path = "c:/Users/Sunny Kumar Sah/OneDrive/Study Materials/Projects/ECS/Ver 1.0/Frontend/smart-trolley/src/app/dashboard/page.tsx"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Add imports at top
import_str = """import React, { useEffect, useState, Suspense } from 'react';
import { Canvas } from '@react-three/fiber';
import { OrbitControls, useGLTF, Stage } from '@react-three/drei';
"""
content = content.replace("import React, { useEffect, useState } from 'react';", import_str)

# Add CartModel component
cart_model_str = """
const CartModel = () => {
  const { scene } = useGLTF('/shopping_cart.glb');
  return <primitive object={scene} />;
};

const AnimatedCounter ="""
content = content.replace("const AnimatedCounter =", cart_model_str)

# Replace the SVG block
svg_block_pattern = r'<div className="relative z-10 flex flex-col items-center">\n<div className="w-44 h-44 sm:w-52 sm:h-52 relative flex items-center justify-center transition-transform duration-500 group-hover:scale-105">.*?<p className="text-\[11px\] text-slate-400 mt-1">Pitch: 0.0° · Yaw: 45\.2° · Roll: 0.0° · Sensor Fusion: Online</p>\n</div>\n</div>'

canvas_block = """<div className="relative z-10 w-full h-full flex flex-col items-center justify-center">
<div className="w-full h-full absolute inset-0 cursor-move">
  <Suspense fallback={<div className="flex h-full items-center justify-center text-xs font-mono text-slate-500">Loading WebGL Engine...</div>}>
    <Canvas camera={{ position: [0, 2, 5], fov: 45 }}>
      <Stage environment="city" intensity={0.6}>
        <CartModel />
      </Stage>
      <OrbitControls autoRotate enableZoom={false} />
    </Canvas>
  </Suspense>
</div>
<div className="absolute bottom-4 left-1/2 -translate-x-1/2 text-center pointer-events-none">
<span className="inline-flex items-center gap-1.5 px-3 py-0.5 rounded-full bg-navy-900/90 backdrop-blur-sm text-white font-mono text-[11px] shadow-sm">
<i className="fa-solid fa-cube text-solar-400"></i>
<span>WebGL Three.js Engine Active</span>
</span>
<p className="text-[11px] text-slate-500 mt-1 font-mono bg-white/50 px-2 py-0.5 rounded">Pitch: 0.0° · Yaw: 45.2° · Roll: 0.0° · Sensor Fusion: Online</p>
</div>
</div>"""

content = re.sub(svg_block_pattern, canvas_block, content, flags=re.DOTALL)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Task 4 modifications written to file.")
