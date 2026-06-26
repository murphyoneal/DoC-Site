const https = require('https')

const MAPBOX = 'pk.eyJ1IjoibXVycGh5MzMiLCJhIjoiY21xc2Z0cXl0MDd0NTJzb2NxbjZhdDh1cSJ9.ihovdf7lzC1CF7W6Px9cQw'
const SB_HOST = 'eaifqorwmgayiqmbtzcg.supabase.co'
const SB_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVhaWZxb3J3bWdheWlxbWJ0emNnIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjMxNjIzOCwiZXhwIjoyMDk3ODkyMjM4fQ.L23cjzASjDbuFQ1zeQt30CThOSX_aRwyWpbl7QLeO-E'
const SB_HEADERS = { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY }

function httpGet(hostname, path, headers) {
  return new Promise((resolve, reject) => {
    https.get({ hostname, path, headers }, (res) => {
      let d = ''
      res.on('data', c => d += c)
      res.on('end', () => { try { resolve(JSON.parse(d)) } catch(e) { resolve([]) } })
    }).on('error', reject)
  })
}

function httpPatch(id, lat, lng) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({ lat, lng, geocoded: true })
    const req = https.request({
      hostname: SB_HOST,
      path: '/rest/v1/contractors?id=eq.' + id,
      method: 'PATCH',
      headers: { ...SB_HEADERS, 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) }
    }, (res) => { res.on('data', () => {}); res.on('end', resolve) })
    req.on('error', reject)
    req.write(body)
    req.end()
  })
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)) }

async function main() {
  let offset = 0, total = 0, success = 0

  while (true) {
    const path = '/rest/v1/contractors?select=id,address_line_1,city,state,zip_code&in_volusia=eq.true&active=eq.true&limit=100&offset=' + offset
    const rows = await httpGet(SB_HOST, path, SB_HEADERS)
    if (!Array.isArray(rows) || rows.length === 0) break

    for (const c of rows) {
      total++
      if (!c.address_line_1 || c.address_line_1.length < 3) {
        console.log('SKIP ' + total + ': ' + c.city)
        continue
      }
      const addr = encodeURIComponent([c.address_line_1, c.city, c.state, c.zip_code].filter(Boolean).join(', '))
      const url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/' + addr + '.json?country=US&limit=1&access_token=' + MAPBOX
      try {
        const geo = await httpGet('api.mapbox.com', '/geocoding/v5/mapbox.places/' + addr + '.json?country=US&limit=1&access_token=' + MAPBOX, {})
        if (geo.features && geo.features.length > 0) {
          const [lng, lat] = geo.features[0].center
          await httpPatch(c.id, lat, lng)
          success++
          console.log('OK ' + total + ': ' + c.city + ' ' + lat.toFixed(4) + ',' + lng.toFixed(4))
        } else {
          console.log('MISS ' + total + ': ' + c.address_line_1 + ', ' + c.city)
        }
      } catch(e) {
        console.log('ERR ' + total + ': ' + e.message)
      }
      await sleep(50)
    }

    offset += rows.length
    if (rows.length < 100) break
  }

  console.log('DONE: ' + success + '/' + total + ' geocoded')
}

main()