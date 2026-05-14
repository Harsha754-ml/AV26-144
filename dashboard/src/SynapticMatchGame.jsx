import React, { useState, useEffect } from 'react';
import { Brain, CheckCircle2, RotateCcw } from 'lucide-react';

const SynapticMatchGame = ({ flashcards }) => {
  const [cards, setCards] = useState([]);
  const [flippedIndices, setFlippedIndices] = useState([]);
  const [matchedIds, setMatchedIds] = useState(new Set());
  const [moves, setMoves] = useState(0);

  useEffect(() => {
    if (flashcards && flashcards.length > 0) {
      // Pick up to 6 flashcards to make 12 cards total (Q&A pairs)
      const selected = flashcards.slice(0, 6);
      
      const gameCards = [];
      selected.forEach((fc) => {
        gameCards.push({ id: fc.id, type: 'question', text: fc.question });
        gameCards.push({ id: fc.id, type: 'answer', text: fc.answer || 'Answer hidden in memory...' });
      });
      
      // Shuffle
      gameCards.sort(() => Math.random() - 0.5);
      
      setCards(gameCards);
      setFlippedIndices([]);
      setMatchedIds(new Set());
      setMoves(0);
    }
  }, [flashcards]);

  const handleCardClick = (index) => {
    // Prevent clicking if already flipped, matched, or 2 cards are already flipped
    if (
      flippedIndices.includes(index) || 
      matchedIds.has(cards[index].id) ||
      flippedIndices.length === 2
    ) {
      return;
    }

    const newFlipped = [...flippedIndices, index];
    setFlippedIndices(newFlipped);

    if (newFlipped.length === 2) {
      setMoves(m => m + 1);
      const firstCard = cards[newFlipped[0]];
      const secondCard = cards[newFlipped[1]];

      if (firstCard.id === secondCard.id && firstCard.type !== secondCard.type) {
        // Match!
        setTimeout(() => {
          setMatchedIds(prev => new Set(prev).add(firstCard.id));
          setFlippedIndices([]);
        }, 500);
      } else {
        // No match
        setTimeout(() => {
          setFlippedIndices([]);
        }, 1500);
      }
    }
  };

  if (!flashcards || flashcards.length === 0) return null;

  const isComplete = matchedIds.size === Math.min(flashcards.length, 6);

  return (
    <div className="bg-[#0f0f11] rounded-[3.5rem] p-12 border border-white/5 shadow-2xl relative overflow-hidden mt-20">
      <div className="absolute top-0 left-0 w-80 h-80 bg-[#c5a059]/5 rounded-full blur-[100px] -ml-40 -mt-40 pointer-events-none" />
      
      <div className="flex justify-between items-end mb-12 relative z-10">
        <div>
          <h3 className="text-3xl font-black text-[#f4f1ea] font-serif flex items-center gap-4">
            <Brain className="w-8 h-8 text-[#c5a059]" />
            Synaptic Match Protocol
          </h3>
          <p className="text-[#8da290] font-serif italic text-lg mt-2">
            Reinforce neural pathways by matching concepts to their definitions.
          </p>
        </div>
        <div className="text-right">
          <span className="text-[10px] font-black text-slate-500 uppercase tracking-widest block mb-1">Cognitive Load</span>
          <span className="text-3xl font-black text-[#c5a059]">{moves} <span className="text-lg text-slate-600">moves</span></span>
        </div>
      </div>

      {isComplete ? (
        <div className="py-20 flex flex-col items-center justify-center text-center animate-in fade-in duration-1000">
          <div className="w-24 h-24 bg-[#c5a059]/20 rounded-full flex items-center justify-center mb-6 border border-[#c5a059]/50 shadow-[0_0_50px_rgba(197,160,89,0.3)]">
            <CheckCircle2 className="w-12 h-12 text-[#c5a059]" />
          </div>
          <h4 className="text-4xl font-black text-[#f4f1ea] font-serif mb-2">Neural Link Established</h4>
          <p className="text-[#8da290] mb-8 font-serif italic">Completed in {moves} moves. Perfect synaptic alignment.</p>
          <button 
            onClick={() => setCards(c => [...c].sort(() => Math.random() - 0.5)) || setMatchedIds(new Set()) || setFlippedIndices([]) || setMoves(0)}
            className="flex items-center gap-3 px-8 py-4 bg-[#c5a059] text-black font-black uppercase text-xs tracking-widest rounded-full hover:bg-white transition-all hover:scale-105 shadow-xl"
          >
            <RotateCcw className="w-4 h-4" />
            Recalibrate Matrix
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6 relative z-10">
          {cards.map((card, index) => {
            const isFlipped = flippedIndices.includes(index) || matchedIds.has(card.id);
            const isMatched = matchedIds.has(card.id);

            return (
              <div 
                key={index} 
                onClick={() => handleCardClick(index)}
                className={`h-40 perspective-1000 cursor-pointer group`}
              >
                <div className={`relative w-full h-full transition-transform duration-700 preserve-3d ${isFlipped ? '[transform:rotateY(180deg)]' : ''}`}>
                  {/* Front of card (Face down) */}
                  <div className={`absolute w-full h-full backface-hidden bg-[#0a0a0b] rounded-3xl border-2 ${flippedIndices.length === 2 ? 'border-white/5' : 'border-white/10 group-hover:border-[#c5a059]/40'} flex items-center justify-center shadow-lg`}>
                    <Brain className="w-8 h-8 text-white/5" />
                  </div>

                  {/* Back of card (Face up) */}
                  <div className={`absolute w-full h-full backface-hidden [transform:rotateY(180deg)] rounded-3xl p-6 border-2 flex items-center justify-center text-center shadow-2xl ${
                    isMatched ? 'bg-[#c5a059]/10 border-[#c5a059]/40 text-[#c5a059]' : 'bg-[#1a1a1c] border-[#8da290]/30 text-[#f4f1ea]'
                  }`}>
                    <span className="text-xs font-serif font-medium leading-relaxed line-clamp-4">
                      {card.text}
                    </span>
                    {isMatched && (
                      <div className="absolute top-3 right-3">
                        <CheckCircle2 className="w-4 h-4 text-[#c5a059]" />
                      </div>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

export default SynapticMatchGame;
