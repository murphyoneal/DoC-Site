// Which URL does a live QR image encode? Regenerate candidate images with the SAME library and
// options as app/api/qr/[slug]/route.ts and compare the served PNG byte-for-byte. This is how the
// do-c-site.vercel.app encoding was caught; the domain move is the same class of error.
// usage: node scripts/qr-encodes-check.mjs <served-qr-url> <slug> <ref> <size>
import QRCode from 'qrcode'

const [served, slug, ref, size] = process.argv.slice(2)
const res = await fetch(served, { redirect: 'follow' })
const got = Buffer.from(await res.arrayBuffer())

const hosts = ['https://departmentofconstruction.com', 'https://www.departmentofconstruction.com',
  'https://departmentofproperty.com', 'https://do-c-site.vercel.app']
const opts = { type: 'png', width: Number(size), margin: 2, color: { dark: '#1B2A4A', light: '#FAF7F2' }, errorCorrectionLevel: 'M' }

const results = []
for (const h of hosts) {
  const target = ref ? `${h}/c/${slug}?ref=${encodeURIComponent(ref)}` : `${h}/c/${slug}`
  const cand = await QRCode.toBuffer(target, opts)
  results.push({ target, identical: Buffer.compare(cand, got) === 0 })
}
console.log(JSON.stringify({ served, finalUrl: res.url, status: res.status, bytes: got.length,
  cache: res.headers.get('x-vercel-cache'), encodes: results.filter(r => r.identical).map(r => r.target), results }, null, 1))
