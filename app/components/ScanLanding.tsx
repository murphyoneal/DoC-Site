'use client'

import { useEffect } from 'react'

interface Props {
  slug: string
  displayName: string
  tradeLabel: string
  city: string
  state: string
  tradeCategory: string
  hasWebsite: boolean
  websiteUrl: string | null
  ref_: string
}

export default function ScanLanding({
  slug,
  displayName,
  tradeLabel,
  city,
  state,
  tradeCategory,
  hasWebsite,
  websiteUrl,
  ref_,
}: Props) {
  useEffect(() => {
    fetch('/api/track/scan', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        slug,
        ref: ref_,
        action: 'scan_landing',
        trade_category: tradeCategory,
        city,
        state,
      }),
    }).catch(() => {})
  }, [slug, ref_, tradeCategory, city, state])

  function handleSaveContact() {
    fetch('/api/track/scan', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        slug,
        ref: ref_,
        action: 'save_contact',
        trade_category: tradeCategory,
        city,
        state,
      }),
    }).catch(() => {})
    window.location.href = `/api/vcard/${slug}`
  }

  function handleVisitWebsite() {
    fetch('/api/track/scan', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        slug,
        ref: ref_,
        action: 'visit_website',
        trade_category: tradeCategory,
        city,
        state,
      }),
    }).catch(() => {})
    if (websiteUrl) {
      window.location.href = websiteUrl
    }
  }

  function handleViewProfile() {
    fetch('/api/track/scan', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        slug,
        ref: ref_,
        action: 'view_profile',
        trade_category: tradeCategory,
        city,
        state,
      }),
    }).catch(() => {})
    window.location.href = `/c/${slug}`
  }

  return (
    <div
      style={{
        minHeight: '100vh',
        background: 'var(--color-cream)',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '2rem 1rem',
        fontFamily: 'Arial, sans-serif',
      }}
    >
      <div style={{ marginBottom: '2rem', opacity: 0.5 }}>
        <span style={{ fontSize: '0.75rem', letterSpacing: '0.15em', color: 'var(--color-navy)', fontWeight: 700 }}>
          DEPARTMENT OF CONSTRUCTION
        </span>
      </div>

      <div
        style={{
          background: 'white',
          borderRadius: '16px',
          padding: '2rem',
          width: '100%',
          maxWidth: '360px',
          textAlign: 'center',
          boxShadow: '0 4px 24px rgba(0,0,0,0.08)',
          marginBottom: '1.5rem',
        }}
      >
        <h1
          style={{
            fontSize: '1.4rem',
            fontFamily: 'Georgia, serif',
            color: 'var(--color-navy)',
            marginBottom: '0.25rem',
          }}
        >
          {displayName}
        </h1>
        <p style={{ fontSize: '0.9rem', color: 'var(--color-bronze)', marginBottom: '0.25rem' }}>
          {tradeLabel}
        </p>
        {city && state && (
          <p style={{ fontSize: '0.8rem', color: 'var(--color-sage)' }}>
            {city}, {state}
          </p>
        )}
      </div>

      <div
        style={{
          width: '100%',
          maxWidth: '360px',
          display: 'flex',
          flexDirection: 'column',
          gap: '0.75rem',
        }}
      >
        <button
          onClick={handleSaveContact}
          style={{
            width: '100%',
            padding: '1rem',
            borderRadius: '10px',
            background: 'var(--color-navy)',
            color: 'white',
            fontSize: '1rem',
            fontWeight: 600,
            border: 'none',
            cursor: 'pointer',
          }}
        >
          📇 Save Contact
        </button>

        {hasWebsite && websiteUrl && (
          <button
            onClick={handleVisitWebsite}
            style={{
              width: '100%',
              padding: '1rem',
              borderRadius: '10px',
              background: 'var(--color-bronze)',
              color: 'white',
              fontSize: '1rem',
              fontWeight: 600,
              border: 'none',
              cursor: 'pointer',
            }}
          >
            🌐 Visit Website
          </button>
        )}

        <button
          onClick={handleViewProfile}
          style={{
            width: '100%',
            padding: '0.85rem',
            borderRadius: '10px',
            background: 'transparent',
            color: 'var(--color-navy)',
            fontSize: '0.9rem',
            fontWeight: 500,
            border: '1px solid var(--color-light-gray)',
            cursor: 'pointer',
          }}
        >
          View Full Profile →
        </button>
      </div>

      <p style={{ marginTop: '2rem', fontSize: '0.7rem', color: 'var(--color-sage)', textAlign: 'center' }}>
        Licensed contractor data from official government registries.
        <br />
        <a href="/disclaimer" style={{ color: 'var(--color-sage)', textDecoration: 'underline' }}>
          Disclaimer
        </a>
      </p>
    </div>
  )
}