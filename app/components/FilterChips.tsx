'use client'

import { MAP_TRADE_CATEGORIES, SEARCH_ONLY_TRADE_CATEGORIES } from '@/lib/trade-categories'

interface FilterChipsProps {
  selected: string | null
  onSelect: (value: string | null) => void
}

// TWO KINDS OF CHIP, AND THEY MUST LOOK DIFFERENT (ruling 951).
// The map draws construction listings that carry coordinates. MAP_TRADE_CATEGORIES are the trades the
// map can actually show (pins are at least half their records), and they FILTER the map.
// SEARCH_ONLY_TRADE_CATEGORIES (Electrical, Alarm System) come from the electrical board's file, which
// has no coordinates: as map filters they would draw one pin and none. They are not hidden, because the
// register holds them. They are links into the two-board register search, styled and labelled as a
// different action, so a chip that looks like a filter never silently returns an empty map.
//
// No Emergency chip: it filtered on emergency_available, which no business has stated (NULL on
// every row since 136c). It always showed an empty map.
export default function FilterChips({ selected, onSelect }: FilterChipsProps) {
  return (
    <div className="flex gap-2 overflow-x-auto pb-1 scrollbar-none items-center" style={{ scrollbarWidth: 'none' }}>
      {/* All trades */}
      <button
        className={`filter-chip ${!selected ? 'active' : ''}`}
        onClick={() => { onSelect(null) }}
      >
        All Trades
      </button>

      {/* Trades the map can show: filter the map */}
      {MAP_TRADE_CATEGORIES.map(cat => (
        <button
          key={cat.category}
          className={`filter-chip ${selected === cat.category ? 'active' : ''}`}
          onClick={() => onSelect(selected === cat.category ? null : cat.category)}
        >
          {cat.label}
        </button>
      ))}

      {/* Trades the map cannot show: open the register search instead */}
      {SEARCH_ONLY_TRADE_CATEGORIES.length > 0 && (
        <span className="text-xs whitespace-nowrap" style={{ color: 'var(--color-sage)', paddingLeft: 6 }}>
          Not on the map, search:
        </span>
      )}
      {SEARCH_ONLY_TRADE_CATEGORIES.map(cat => (
        <a
          key={cat.category}
          href={`/c?q=${encodeURIComponent(cat.label)}`}
          className="filter-chip"
          data-chip-kind="search"
          title={`${cat.label} licences come from the Electrical Contractors' Licensing Board file, which has no map locations. This opens the register search.`}
          style={{ borderStyle: 'dashed', textDecoration: 'none' }}
        >
          {cat.label} search &#8599;
        </a>
      ))}
    </div>
  )
}
