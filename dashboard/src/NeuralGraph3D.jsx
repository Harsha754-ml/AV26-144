import React, { useRef, useState, useEffect, useMemo } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { OrbitControls, Text, Float } from '@react-three/drei';
import * as THREE from 'three';

const API_BASE = "http://127.0.0.1:8000";

// 3D Node component
function NeuralNode({ position, color, size, name, retention, onClick }) {
  const meshRef = useRef();
  const glowRef = useRef();
  const [hovered, setHovered] = useState(false);

  useFrame((state) => {
    if (meshRef.current) {
      meshRef.current.rotation.y += 0.005;
      // Pulse effect
      const scale = 1 + Math.sin(state.clock.elapsedTime * 2 + position[0]) * 0.05;
      meshRef.current.scale.setScalar(scale);
    }
    if (glowRef.current) {
      glowRef.current.material.opacity = 0.15 + Math.sin(state.clock.elapsedTime * 3) * 0.05;
    }
  });

  return (
    <group position={position}>
      {/* Glow sphere */}
      <mesh ref={glowRef}>
        <sphereGeometry args={[size * 1.8, 16, 16]} />
        <meshBasicMaterial color={color} transparent opacity={0.1} />
      </mesh>
      
      {/* Main node */}
      <mesh
        ref={meshRef}
        onClick={onClick}
        onPointerOver={() => setHovered(true)}
        onPointerOut={() => setHovered(false)}
      >
        <dodecahedronGeometry args={[size, 1]} />
        <meshStandardMaterial
          color={hovered ? '#ffffff' : color}
          emissive={color}
          emissiveIntensity={hovered ? 0.8 : 0.3}
          metalness={0.7}
          roughness={0.2}
        />
      </mesh>

      {/* Label */}
      <Text
        position={[0, -size - 0.4, 0]}
        fontSize={0.25}
        color="#f4f1ea"
        anchorX="center"
        anchorY="top"
        font={undefined}
      >
        {name.length > 15 ? name.substring(0, 15) + '...' : name}
      </Text>

      {/* Retention badge */}
      <Text
        position={[0, size + 0.3, 0]}
        fontSize={0.2}
        color={color}
        anchorX="center"
        anchorY="bottom"
        font={undefined}
      >
        {retention}%
      </Text>
    </group>
  );
}

// 3D Edge (connection line)
function NeuralEdge({ start, end, color = '#c5a059' }) {
  const ref = useRef();
  
  const points = useMemo(() => {
    return [new THREE.Vector3(...start), new THREE.Vector3(...end)];
  }, [start, end]);

  const geometry = useMemo(() => {
    return new THREE.BufferGeometry().setFromPoints(points);
  }, [points]);

  useFrame((state) => {
    if (ref.current) {
      ref.current.material.opacity = 0.2 + Math.sin(state.clock.elapsedTime * 2) * 0.1;
    }
  });

  return (
    <line ref={ref} geometry={geometry}>
      <lineBasicMaterial color={color} transparent opacity={0.3} />
    </line>
  );
}

// Floating particles
function Particles() {
  const count = 50;
  const ref = useRef();
  
  const positions = useMemo(() => {
    const pos = new Float32Array(count * 3);
    for (let i = 0; i < count * 3; i++) {
      pos[i] = (Math.random() - 0.5) * 15;
    }
    return pos;
  }, []);

  useFrame((state) => {
    if (ref.current) {
      ref.current.rotation.y += 0.0005;
      ref.current.rotation.x += 0.0002;
    }
  });

  return (
    <points ref={ref}>
      <bufferGeometry>
        <bufferAttribute attach="attributes-position" count={count} array={positions} itemSize={3} />
      </bufferGeometry>
      <pointsMaterial size={0.03} color="#c5a059" transparent opacity={0.4} sizeAttenuation />
    </points>
  );
}

// Main 3D Scene
function Scene({ nodes, edges }) {
  return (
    <>
      <ambientLight intensity={0.3} />
      <pointLight position={[10, 10, 10]} intensity={1} color="#c5a059" />
      <pointLight position={[-10, -10, -5]} intensity={0.5} color="#8da290" />
      
      <Particles />
      
      {/* Edges */}
      {edges.map((edge, i) => {
        const sourceNode = nodes.find(n => n.id === edge.source);
        const targetNode = nodes.find(n => n.id === edge.target);
        if (!sourceNode || !targetNode) return null;
        return (
          <NeuralEdge
            key={i}
            start={sourceNode.position}
            end={targetNode.position}
            color="#c5a059"
          />
        );
      })}

      {/* Nodes */}
      {nodes.map((node) => (
        <Float key={node.id} speed={1.5} rotationIntensity={0.2} floatIntensity={0.3}>
          <NeuralNode
            position={node.position}
            color={node.color}
            size={node.size}
            name={node.name}
            retention={node.retention}
          />
        </Float>
      ))}

      <OrbitControls enableZoom={true} enablePan={true} autoRotate autoRotateSpeed={0.5} />
    </>
  );
}

// Main component
const NeuralGraph3D = () => {
  const [graphData, setGraphData] = useState({ nodes: [], edges: [] });

  useEffect(() => {
    fetch(`${API_BASE}/knowledge-graph`)
      .then(r => r.json())
      .then(data => {
        if (data.nodes && data.nodes.length > 0) {
          // Assign 3D positions in a sphere layout
          const nodes = data.nodes.map((n, i) => {
            const phi = Math.acos(-1 + (2 * i) / data.nodes.length);
            const theta = Math.sqrt(data.nodes.length * Math.PI) * phi;
            const radius = 3 + n.val * 0.2;
            return {
              ...n,
              position: [
                radius * Math.cos(theta) * Math.sin(phi),
                radius * Math.sin(theta) * Math.sin(phi),
                radius * Math.cos(phi),
              ],
              size: 0.3 + (n.val || 5) * 0.04,
              color: n.color || '#c5a059',
            };
          });
          setGraphData({ nodes, edges: data.links || [] });
        }
      })
      .catch(() => {});
  }, []);

  return (
    <div className="w-full h-full relative">
      <Canvas camera={{ position: [0, 0, 8], fov: 60 }} style={{ background: '#0a0a0b' }}>
        <Scene nodes={graphData.nodes} edges={graphData.edges} />
      </Canvas>

      {/* Overlay UI */}
      <div className="absolute top-4 left-4 bg-[#0f0f11]/80 backdrop-blur-sm rounded-2xl p-4 border border-white/5">
        <p className="text-[10px] font-black text-[#c5a059] uppercase tracking-widest mb-2">WebGL Neural Graph</p>
        <p className="text-[9px] text-slate-500">Drag to rotate • Scroll to zoom • {graphData.nodes.length} nodes</p>
      </div>

      {/* Legend */}
      <div className="absolute bottom-4 left-4 bg-[#0f0f11]/80 backdrop-blur-sm rounded-2xl p-4 border border-white/5">
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-[#c5a059]" />
            <span className="text-[9px] font-black text-slate-500">Strong</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-[#f59e0b]" />
            <span className="text-[9px] font-black text-slate-500">Decaying</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-[#f43f5e]" />
            <span className="text-[9px] font-black text-slate-500">Critical</span>
          </div>
        </div>
      </div>

      {/* Empty state */}
      {graphData.nodes.length === 0 && (
        <div className="absolute inset-0 flex items-center justify-center">
          <div className="text-center">
            <p className="text-2xl font-black text-[#f4f1ea] font-serif mb-2">No Neural Data</p>
            <p className="text-slate-500 text-sm">Upload content to build your 3D knowledge graph</p>
          </div>
        </div>
      )}
    </div>
  );
};

export default NeuralGraph3D;
