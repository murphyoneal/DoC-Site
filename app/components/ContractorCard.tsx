import Link from 'next/link'
import type { Contractor } from '@/types/contractor'
import StatusBadge from './StatusBadge'

interface ContractorCardProps {
  contractor: Contractor
}

export default function ContractorCard({ contractor: c }: ContractorCardProps) {
  return (
    <Link
      href={`/c/${c.slug}`}
      className="block rounded-lg p-4 transition-shadow hover:shadow-md"
      style={{
        background: 'var(--color-white)',
        border: '1px solid var(--color-light-gray)',
      }}
    >
      <div className="flex items-start justify-between gap-2">
        <div className="flex-1 min-w-0">
          <p
            className="font-semibold text-sm truncate"
            style={{ color: 'var(--color-navy)', fontFamily: 'Georgia, serif' }}
          >
            {c.display_name}
          </p>
          <p className="text-xs mt-0.5 truncate" style={{ color: 'var(--color-bronze)' }}>
            {c.trade_label ?? c.doc_category ?? 'Contractor'}
          </p>
          {c.city && (
            <p className="text-xs mt-0.5" style={{ color: 'var(--color-sage)' }}>
              {c.city}, {c.state}
            </p>
          )}
        </div>
        <div className="flex flex-col items-end gap-1 shrink-0">
          <StatusBadge status={c.license_status} size="sm" />
          {c.verified && (
            <span
              className="text-xs px-1.5 py-0.5 rounded-full font-bold"
              style={{ background: '#e8f0fb', color: 'var(--color-navy)' }}
            >
              ✓
            </span>
          )}
        </div>
      </div>
    </Link>
  )
}
