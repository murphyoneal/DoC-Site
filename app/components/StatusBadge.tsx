import type { LicenseStatus } from '@/types/contractor'

interface StatusBadgeProps {
  status: LicenseStatus | null | undefined
  size?: 'sm' | 'md'
}

const STATUS_CONFIG: Record<string, { label: string; bg: string; text: string }> = {
  active:    { label: 'Active',    bg: '#e8f5ed', text: '#2d7d46' },
  inactive:  { label: 'Inactive',  bg: '#f5f0e8', text: '#8B6F47' },
  expired:   { label: 'Expired',   bg: '#fdecea', text: '#c0392b' },
  revoked:   { label: 'Revoked',   bg: '#fdecea', text: '#8e1c0e' },
  suspended: { label: 'Suspended', bg: '#fff3e0', text: '#e67e22' },
}

export default function StatusBadge({ status, size = 'md' }: StatusBadgeProps) {
  const cfg = STATUS_CONFIG[status ?? ''] ?? { label: 'Unknown', bg: '#f0f0f0', text: '#888' }
  const pad = size === 'sm' ? '0.2rem 0.5rem' : '0.25rem 0.65rem'
  const fs  = size === 'sm' ? '0.72rem' : '0.8rem'

  return (
    <span
      style={{
        background: cfg.bg,
        color: cfg.text,
        padding: pad,
        borderRadius: '9999px',
        fontSize: fs,
        fontWeight: 700,
        display: 'inline-flex',
        alignItems: 'center',
        gap: '0.25rem',
      }}
    >
      <span style={{
        width: 6,
        height: 6,
        borderRadius: '50%',
        background: cfg.text,
        display: 'inline-block',
      }} />
      {cfg.label}
    </span>
  )
}
