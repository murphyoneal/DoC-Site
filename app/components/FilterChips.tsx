'use client'

import { TRADE_CATEGORIES } from '@/lib/trade-categories'

interface FilterChipsProps {
  selected: string | null
  onSelect: (value: string | null) => void
}

// No Emergency chip: it filtered on emergency_available, which no business has stated (NULL on
// every row since 136c). It always showed an empty map.
export default function FilterChips({ selected, onSelect }: FilterChipsProps) {
  return (
    <div className="flex gap-2 overflow-x-auto pb-1 scrollbar-none" style={{ scrollbarWidth: 'none' }}>
      {/* All trades */}
      <button
        className={`filter-chip ${!selected ? 'active' : ''}`}
        onClick={() => { onSelect(null) }}
      >
        All Trades
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
