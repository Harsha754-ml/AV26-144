import React, { useRef, useCallback, useEffect, useState } from 'react';
import ForceGraph2D from 'react-force-graph-2d';

const API_BASE = "http://127.0.0.1:8000";

const KnowledgeGraph = () => {
  const graphRef = useRef();
  const [graphData, setGraphData] = useState({ nodes: [], links: [] });
  const [hoveredNode, setHoveredNode] = useState(null);

  useEffect(() => {
    fetch(`${API_BASE}/knowledge-graph`)
      .then(r => r.json())
      .then(data => {
        if (data.nodes && data.nodes.length > 0) {
          setGraphData(data);
        }
      })
      .catch(() => {});
  }, []);

  const paintNode = useCallback((node, ctx, globalScale) => {
    const size = node.val || 8;
    const isHovered = hoveredNode === node.id;
    
    // Glow effect
    if (isHovered) {
      ctx.beginPath();
      ctx.arc(node.x, node.y, size + 6, 0, 2 * Math.PI);
      ctx.fillStyle = `${node.color}33`;
      ctx.fill();
    }
    
    // Node circle
    ctx.beginPath();
    ctx.arc(node.x, node.y, size, 0, 2 * Math.PI);
    ctx.fillStyle = isHovered ? '#ffffff' : node.color;
    ctx.fill();
    ctx.strokeStyle = `${node.color}88`;
    ctx.lineWidth = 2;
    ctx.stroke();
    
    // Label
    const label = node.name || node.id;
    const fontSize = Math.max(10 / globalScale, 3);
    ctx.font = `bold ${fontSize}px serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = isHovered ? '#c5a059' : '#f4f1ea';
    ctx.fillText(label, node.x, node.y + size + fontSize + 2);
    
    // Retention badge
    ctx.font = `bold ${fontSize * 0.8}px monospace`;
    ctx.fillStyle = node.color;
    ctx.fillText(`${node.retention}%`, node.x, node.y);
  }, [hoveredNode]);

  const paintLink = useCallback((link, ctx) => {
    ctx.beginPath();
    ctx.moveTo(link.source.x, link.source.y);
    ctx.lineTo(link.target.x, link.target.y);
    ctx.strokeStyle = 'rgba(197, 160, 89, 0.15)';
    ctx.lineWidth = 1.5;
    ctx.stroke();
  }, []);

  return (
    <div className="w-full h-full rounded-3xl overflow-hidden bg-[#0a0a0b] relative">
      <ForceGraph2D
        ref={graphRef}
        graphData={graphData}
        nodeCanvasObject={paintNode}
        linkCanvasObject={paintLink}
        nodePointerAreaPaint={(node, color, ctx) => {
          ctx.beginPath();
          ctx.arc(node.x, node.y, node.val + 5, 0, 2 * Math.PI);
          ctx.fillStyle = color;
          ctx.fill();
        }}
        onNodeHover={(node) => setHoveredNode(node ? node.id : null)}
        backgroundColor="#0a0a0b"
        linkColor={() => 'rgba(197, 160, 89, 0.1)'}
        d3AlphaDecay={0.02}
        d3VelocityDecay={0.3}
        warmupTicks={50}
        cooldownTicks={100}
      />
      
      {/* Legend */}
      <div className="absolute bottom-4 left-4 bg-[#0f0f11]/90 backdrop-blur-sm rounded-2xl p-4 border border-white/5">
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-[#c5a059]" />
            <span className="text-[9px] font-black text-slate-500 uppercase">Strong (70%+)</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-[#f59e0b]" />
            <span className="text-[9px] font-black text-slate-500 uppercase">Decaying (50-70%)</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-[#f43f5e]" />
            <span className="text-[9px] font-black text-slate-500 uppercase">Critical (&lt;50%)</span>
          </div>
        </div>
      </div>

      {/* Hovered node info */}
      {hoveredNode && (
        <div className="absolute top-4 right-4 bg-[#0f0f11]/90 backdrop-blur-sm rounded-2xl p-4 border border-[#c5a059]/20">
          <p className="text-sm font-black text-[#f4f1ea]">{hoveredNode}</p>
          <p className="text-[10px] text-slate-500 mt-1">Click to explore</p>
        </div>
      )}
    </div>
  );
};

export default KnowledgeGraph;
