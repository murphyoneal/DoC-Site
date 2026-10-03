export {}

export type LicenseStatus = 'active' | 'inactive' | 'expired' | 'revoked' | 'suspended'
export type Tier = 'public' | 'verified' | 'member'
export type SubscriptionTier = 'listed' | 'enhanced' | 'member'
export type ProfileTierLabel = 'Listed' | 'Claimed' | 'Enhanced' | 'Verified'
export interface ContractorMapPin {
  id: string
  slug: string
  display_name: string
  trade_label: string | null
  doc_category: string | null
  city: string | null
  state: string | null
  zip_code: string | null
  lat: number
  lng: number
  tier: Tier | null
  license_status: LicenseStatus | null
}
export interface Contractor {
  id: string
  slug: string
  business_name: string
  trading_name: string | null
  display_name: string
  trade_code: string | null
  trade_label: string | null
  doc_category: string | null
  classifications: string[] | null
  license_number: string | null
  license_status: LicenseStatus | null
  expiry_date: string | null
  address_line_1: string | null
  city: string | null
  state: string | null
  zip_code: string | null
  county_code: string | null
  country_code: string | null
  lat: number | null
  lng: number | null
  geocoded: boolean | null
  geocode_quality: string | null
  tier: Tier | null
  claimed: boolean | null
  active: boolean | null
  profile_score: number | null
  profile_tier_label: ProfileTierLabel | null
  source: string | null
  source_url: string | null
  subscription_tier: SubscriptionTier | null
  created_at: string | null
  updated_at: string | null
}
export interface BoundingBox {
  north: number
  south: number
  east: number
  west: number
}
// TRADE_CATEGORIES was here: a hand-written list of fifteen {value,label} pairs. REMOVED (ruling 949).
// It was the third copy of this vocabulary and the stalest — it keyed "pool" where the data says
// pool_spa, offered "concrete" which does not exist in trade_display_category at all, and had no
// entry for building_contractor, residential_contractor, specialty, alarm_system or
// underground_utility. Nothing imported it, which is what made it dangerous: an exported const with
// the right name and the wrong contents is one autocomplete away from shipping.
//
// The one list is CHIP_CATEGORIES in lib/tradeCategories.ts, generated from the trade_chip_map view.
// Import TRADE_CATEGORIES from '@/lib/trade-categories' if you need {value,label} pairs.