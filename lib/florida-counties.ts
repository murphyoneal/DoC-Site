// County landing-page data. Mirrors the /florida/volusia content pattern, but
// data-driven so a page = one entry + a thin route file.
// coNo (DOR county number) is included where confirmed against county_registry,
// for future linking to property/amenity data; optional and unused in rendering.

export interface FloridaCounty {
  slug: string
  name: string        // 'Osceola County'
  shortName: string   // 'Osceola'
  seat: string        // county seat / major city
  coNo?: number       // DOR county number (confirmed ones only)
  cities: { name: string; desc: string }[]
  blurb: string
  permitAuthority: string
  permitUrl: string
}

export const FLORIDA_COUNTIES: FloridaCounty[] = [
  {
    slug: 'miami-dade',
    name: 'Miami-Dade County',
    shortName: 'Miami-Dade',
    seat: 'Miami',
    cities: [
      { name: 'Miami', desc: 'County seat' },
      { name: 'Hialeah', desc: 'Northwest metro' },
      { name: 'Miami Beach', desc: 'Barrier island' },
      { name: 'Coral Gables', desc: 'Historic city' },
      { name: 'Doral', desc: 'West Miami-Dade' },
      { name: 'Homestead', desc: 'South county' },
    ],
    blurb:
      'Miami-Dade is Florida’s most populous county, spanning Miami, Hialeah, Miami Beach and the southern suburbs.',
    permitAuthority: 'Miami-Dade County Department of Regulatory and Economic Resources',
    permitUrl: 'https://www.miamidade.gov/permits/',
  },
  {
    slug: 'orange',
    name: 'Orange County',
    shortName: 'Orange',
    seat: 'Orlando',
    coNo: 48,
    cities: [
      { name: 'Orlando', desc: 'County seat' },
      { name: 'Apopka', desc: 'Northwest county' },
      { name: 'Winter Park', desc: 'North metro' },
      { name: 'Ocoee', desc: 'West Orange' },
      { name: 'Winter Garden', desc: 'West county' },
      { name: 'Maitland', desc: 'North metro' },
    ],
    blurb:
      'Orange County anchors Central Florida around Orlando, from Winter Park and Maitland to the western communities of Ocoee and Winter Garden.',
    permitAuthority: 'Orange County Division of Building Safety',
    permitUrl: 'https://www.orangecountyfl.net/PermitsLicenses/Permits.aspx',
  },
  {
    slug: 'seminole',
    name: 'Seminole County',
    shortName: 'Seminole',
    seat: 'Sanford',
    coNo: 69,
    cities: [
      { name: 'Sanford', desc: 'County seat' },
      { name: 'Altamonte Springs', desc: 'South county' },
      { name: 'Lake Mary', desc: 'Central county' },
      { name: 'Oviedo', desc: 'East county' },
      { name: 'Winter Springs', desc: 'Central county' },
      { name: 'Longwood', desc: 'South county' },
    ],
    blurb:
      'Seminole County sits north of Orlando, covering Sanford, Lake Mary, Altamonte Springs and the SunRail commuter corridor.',
    permitAuthority: 'Seminole County Building Division',
    permitUrl: 'https://www.seminolecountyfl.gov/departments-services/development-services/building/',
  },
  {
    slug: 'osceola',
    name: 'Osceola County',
    shortName: 'Osceola',
    seat: 'Kissimmee',
    coNo: 59,
    cities: [
      { name: 'Kissimmee', desc: 'County seat' },
      { name: 'St. Cloud', desc: 'East county' },
      { name: 'Celebration', desc: 'Planned community' },
      { name: 'Poinciana', desc: 'Southwest county' },
      { name: 'Buenaventura Lakes', desc: 'North county' },
      { name: 'Harmony', desc: 'East county' },
    ],
    blurb:
      'Osceola County runs south of Orlando through Kissimmee and St. Cloud, including the planned communities of Celebration and Harmony.',
    permitAuthority: 'Osceola County Building Division',
    permitUrl: 'https://www.osceola.org/agencies-departments/community-development/building-division/',
  },
  {
    slug: 'lake',
    name: 'Lake County',
    shortName: 'Lake',
    seat: 'Tavares',
    coNo: 35,
    cities: [
      { name: 'Clermont', desc: 'South county' },
      { name: 'Leesburg', desc: 'West county' },
      { name: 'Mount Dora', desc: 'Historic city' },
      { name: 'Tavares', desc: 'County seat' },
      { name: 'Eustis', desc: 'Central county' },
      { name: 'Groveland', desc: 'South county' },
    ],
    blurb:
      'Lake County spreads across Central Florida’s hill country, from Clermont and Groveland to the historic lakeside towns of Mount Dora, Eustis and Tavares.',
    permitAuthority: 'Lake County Building Services',
    permitUrl: 'https://www.lakecountyfl.gov/departments/building_services/',
  },
]

export function getCounty(slug: string): FloridaCounty | undefined {
  return FLORIDA_COUNTIES.find(c => c.slug === slug)
}
