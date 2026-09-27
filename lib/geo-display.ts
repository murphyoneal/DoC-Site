// Client-safe geography helpers for the self-registration pages (no keys, no fetches).

export type Geo = { geo_id: string; name: string; admin1_abbr: string | null; level_type: string | null }

// "Fairfax" (a county) vs "Fairfax city" (an independent city): the name carries its own suffix
// except for plain counties, whose " County" was dropped when the Census list was seeded (141b).
export function countyDisplay(name: string, level: string | null): string {
  return level === 'county' ? `${name} County` : name
}
