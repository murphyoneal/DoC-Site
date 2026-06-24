import Link from 'next/link'

export default function NotFound() {
  return (
    <div className="max-w-xl mx-auto px-4 py-20 text-center">
      <p
        className="text-6xl font-bold mb-4"
        style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}
      >
        404
      </p>
      <h1
        className="text-xl font-bold mb-3"
        style={{ fontFamily: 'Georgia, serif', color: 'var(--color-bronze)' }}
      >
        Page Not Found
      </h1>
      <p className="mb-6 text-sm" style={{ color: 'var(--color-sage)' }}>
        This page doesn&apos;t exist. If you followed a contractor link, the profile may
        have been removed from the registry.
      </p>
      <Link
        href="/"
        className="inline-block px-5 py-2.5 rounded-lg font-semibold text-sm"
        style={{ background: 'var(--color-navy)', color: 'var(--color-white)' }}
      >
        Back to Map
      </Link>
    </div>
  )
}
