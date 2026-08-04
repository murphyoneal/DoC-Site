import { getSupabaseAdmin } from '@/lib/supabase/server'

// Purchase state for the PIR paywall. A parcel's report unlocks once ANY paid purchase
// exists for it (pir_is_unlocked), so a forwarded link works and the recipient buys
// their own parcel (doorway C3). Served through SECURITY DEFINER RPCs.

export const purchaseSocket = {
  async isUnlocked(coNo: number, parcelId: string): Promise<boolean> {
    try {
      const sb = getSupabaseAdmin()
      const { data, error } = await sb.rpc('pir_is_unlocked', { p_co_no: coNo, p_parcel_id: parcelId })
      if (error) {
        console.error('[purchaseSocket] pir_is_unlocked failed:', error.message)
        return false
      }
      return data === true
    } catch (e) {
      console.error('[purchaseSocket] pir_is_unlocked threw:', e instanceof Error ? e.message : String(e))
      return false
    }
  },
}
