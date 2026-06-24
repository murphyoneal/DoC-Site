'use client'

import { TRADE_CATEGORIES } from '@/types/contractor'

interface FilterChipsProps {
  selected: string | null
  onSelect: (value: string | null) => void
  emergency: boolean
  onEmergencyToggle: () => void
}

export default function FilterChips({
  selected,
  onSelect,
  emergency,
  onEmergencyToggle,
}: FilterChipsProps) {
  return (
    <div className="flex gap-2 overflow-x-auto pb-1 scrollbar-none" style={{ scrollbarWidth: 'none' }}>
      {/* All trades */}
      <button
        className={`filter-chip ${!selected && !emergency ? 'active' : ''}`}
        onClick={() => { onSelect(null) }}
      >
        All Trades
      </button>

      {/* Emergency toggle */}
      <button
        className={`filter-chip ${emergency ? 'active' : ''}`}
        style={emergency ? { background: '#C0392B', borderColor: '#C0392B' } : { borderColor: '#C0392B', color: '#C0392B' }}
        onClick={onEmergencyToggle}
      >
        🚨 Emergency
      </button>

      {/* Trade categories */}
      {TRADE_CATEGORIES.map(cat => (
        <button
          key={cat.value}
          className={`filter-chip ${selected === cat.value ? 'active' : ''}`}
          onClick={() => onSelect(selected === cat.value ? null : cat.value)}
        >
          {cat.label}
        </button>
      ))}
    </div>
  )
}
