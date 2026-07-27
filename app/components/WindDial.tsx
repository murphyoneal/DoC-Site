// Honest wind figure. We have the prevailing direction plus average and gust
// speed (county ASOS baseline) — NOT a full 16-point frequency distribution, so
// this is deliberately a "prevailing wind" dial, not a fabricated windrose with
// invented per-sector frequencies. Pure SVG, server-renderable.

import type { PirWind } from '@/types/pir'

const ANGLE: Record<string, number> = {
  N: 0, NNE: 22.5, NE: 45, ENE: 67.5, E: 90, ESE: 112.5, SE: 135, SSE: 157.5,
  S: 180, SSW: 202.5, SW: 225, WSW: 247.5, W: 270, WNW: 292.5, NW: 315, NNW: 337.5,
}

export default function WindDial({ wind }: { wind: PirWind }) {
  const dir = wind.prevailingDirection?.toUpperCase()
  const fromA = dir && dir in ANGLE ? ANGLE[dir] : null
  const S = 104, cx = S / 2, cy = S / 2, R = 40
  const rad = fromA == null ? 0 : (fromA * Math.PI) / 180
  // point on the ring where the wind comes FROM
  const fx = cx + R * Math.sin(rad), fy = cy - R * Math.cos(rad)

  return (
    <div style={{ display: 'flex', gap: 14, alignItems: 'center' }}>
      <svg width={S} height={S} viewBox={`0 0 ${S} ${S}`} aria-label="Prevailing wind dial">
        <circle cx={cx} cy={cy} r={R} fill="none" stroke="var(--color-light-gray)" strokeWidth={1.5} />
        <circle cx={cx} cy={cy} r={R * 0.55} fill="none" stroke="var(--color-light-gray)" strokeWidth={1} />
        {(['N', 'E', 'S', 'W'] as const).map((d, i) => {
          const a = (i * 90 * Math.PI) / 180
          const tx = cx + (R + 7) * Math.sin(a), ty = cy - (R + 7) * Math.cos(a)
          return <text key={d} x={tx} y={ty + 3} textAnchor="middle" fontSize={9} fill="var(--color-sage)" fontWeight={700}>{d}</text>
        })}
        {fromA != null && (
          <g>
            {/* arrow from the source direction toward centre (where the wind blows to) */}
            <line x1={fx} y1={fy} x2={cx} y2={cy} stroke="var(--color-navy)" strokeWidth={3} strokeLinecap="round" />
            <circle cx={fx} cy={fy} r={4.5} fill="var(--color-gold)" stroke="#fff" strokeWidth={1} />
          </g>
        )}
      </svg>
      <div style={{ fontSize: 12, color: 'var(--color-ink)', lineHeight: 1.5 }}>
        <div style={{ fontFamily: 'Georgia, serif', fontWeight: 700, color: 'var(--color-navy)' }}>
          Prevailing wind{dir ? ` — from ${dir}` : ''}
        </div>
        {wind.avgSpeedMph != null && <div>Avg {wind.avgSpeedMph} mph{wind.maxGustMph != null ? ` · gust ${wind.maxGustMph} mph` : ''}</div>}
        {wind.designSpeedMph != null && <div style={{ color: 'var(--color-sage)' }}>FBC design {wind.designSpeedMph} mph{wind.windSpeedZone ? ` (Zone ${wind.windSpeedZone})` : ''}</div>}
        <div style={{ color: 'var(--color-sage)', fontSize: 10.5, marginTop: 2 }}>Prevailing direction — not a frequency rose.</div>
      </div>
    </div>
  )
}
