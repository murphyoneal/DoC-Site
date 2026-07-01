const https = require('https')

const MAPBOX = 'pk.eyJ1IjoibXVycGh5MzMiLCJhIjoiY21xc2Z0cXl0MDd0NTJzb2NxbjZhdDh1cSJ9.ihovdf7lzC1CF7W6Px9cQw'
const SB_HOST = 'eaifqorwmgayiqmbtzcg.supabase.co'
const SB_KEY = 'sb_secret_POUAGzaloJwoWGjWL7DVcQ_b2-NIQ-z'
const HEADERS = { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY }

// Known city centres for Volusia County
const CITY_CENTRES = {
  'DAYTONA BEACH': [29.2108, -81.0228],
  'DAYTONA BEACH SHORES': [29.1877, -80.9967],
  'PORT ORANGE': [29.1080, -81.0089],
  'ORMOND BEACH': [29.2858, -81.0562],
  'NEW SMYRNA BEACH': [29.0258, -80.9270],
  'EDGEWATER': [28.9753, -80.9478],
  'DELTONA': [28.9005, -81.2637],
  'DELAND': [29.0286, -81.3031],
  'HOLLY HILL': [29.2480, -81.0395],
  'SOUTH DAYTONA': [29.1697, -81.0101],
  'DEBARY': [28.8853, -81.3318],
  'ORANGE CITY': [28.9489, -81.2987],
  'LAKE HELEN': [28.9878, -81.2312],
  'ENTERPRISE': [28.8633, -81.2290],
  'OSTEEN': [28.8422, -81.1459],
  'OAK HILL': [28.8761, -80.8520],
  'PONCE INLET': [29.0930, -80.9287],
  'PIERSON': [29.2397, -81.4676],
}

function distanceMiles(lat1, lng1, lat2, lng2) {
  const R = 3958.8
  const dLat = (lat2 - lat1) * Math.PI / 180
  const dLng = (lng2 - lng1) * Math.PI / 180
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLng/2) * Math.sin(dLng/2)
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
}

function httpGet(hostname, path, headers) {
  return new Promise(function(resolve, reject) {
    https.get({ hostname, path, headers }, function(res) {
      let d = ''
      res.on('data', function(c) { d += c })
      res.on('end', function() { try { resolve(JSON.parse(d)) } catch(e) { resolve([]) } })
    }).on('error', reject)
  })
}

function patch(id, lat, lng) {
  return new Promise(function(resolve, reject) {
    const body = JSON.stringify({ lat: lat, lng: lng })
    const req = https.request({
      hostname: SB_HOST,
      path: '/rest/v1/contractors?id=eq.' + id,
      method: 'PATCH',
      headers: Object.assign({}, HEADERS, { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) })
    }, function(res) { res.on('data', function() {}); res.on('end', resolve) })
    req.on('error', reject)
    req.write(body)
    req.end()
  })
}

function geocode(address) {
  const encoded = encodeURIComponent(address)
  const path = '/geocoding/v5/mapbox.places/' + encoded + '.json?country=US&limit=1&access_token=' + MAPBOX
  return httpGet('api.mapbox.com', path, {})
}

function sleep(ms) { return new Promise(function(r) { setTimeout(r, ms) }) }

async function main() {
  let offset = 0
  let total = 0
  let fixed = 0
  let skipped = 0

  while (true) {
    const path = '/rest/v1/contractors?select=id,display_name,address_line_1,city,state,zip_code,lat,lng&in_volusia=eq.true&active=eq.true&geocoded=eq.true&limit=100&offset=' + offset
    const rows = await httpGet(SB_HOST, path, HEADERS)
    if (!Array.isArray(rows) || rows.length === 0) break

    for (const c of rows) {
      total++
      const cityUpper = (c.city || '').toUpperCase()
      const centre = CITY_CENTRES[cityUpper]

      if (!centre) {
        skipped++
        continue
      }

      const dist = distanceMiles(c.lat, c.lng, centre[0], centre[1])

      if (dist <= 15) {
        continue // Pin is within 15 miles of city centre â€” acceptable
      }

      // Pin is too far from stated city â€” re-geocode with city+state+zip only
      console.log('FIX ' + total + ': ' + c.display_name + ' (' + c.city + ') is ' + dist.toFixed(1) + ' miles off')

      const address = (c.city || '') + ', ' + (c.state || '') + ' ' + (c.zip_code || '')
      try {
        const geo = await geocode(address)
        if (geo.features && geo.features.length > 0) {
          const lng = geo.features[0].center[0]
          const lat = geo.features[0].center[1]
          await patch(c.id, lat, lng)
          fixed++
          console.log('  -> ' + lat.toFixed(4) + ', ' + lng.toFixed(4))
        }
      } catch(e) {
        console.log('  ERR: ' + e.message)
      }
      await sleep(100)
    }

    offset += rows.length
    if (rows.length < 100) break
  }

  console.log('Done. Checked ' + total + '. Fixed ' + fixed + '. Skipped ' + skipped + ' (unknown city).')
}

main()
