# CAMA Probe — Blocked Counties, Resolved

**Recorded 2026-08-09.** Amends `Bulk_CAMA_and_Tax-Roll_Export_Work-List_for_Florida_s_12_Largest_Counties.md`.

The 9 August probe recorded nine counties blocked with a reason each. Four of those reasons were about the *fetch method*, not the *availability*, and three of them are now resolved. One resolution **changes a county's category** and that correction matters more than the endpoints.

No row counts appear here. Nothing below was downloaded — only the index pages were read.

---

## 1. Hillsborough — the mechanism is solved and the category was wrong

**Blocked as:** ASP.NET viewstate postback.

### The correction, which is the actual finding

The work-list has Hillsborough as **RELATIONAL-ish (parcel + sales + more)**. The index reads:

| file | size | stamped |
|---|---|---|
| `parcel_08_07_2026.zip` | 182 MB | 8/7/2026 |
| `allsales_08_07_2026.zip` | 68 MB | 8/7/2026 |
| `HCparcel_4_public_08_07_2026.zip` | 97 MB | 8/7/2026 |
| `PARCEL_SPREADSHEET.xls` | 537 MB | 8/7/2026 |
| `County_Boundary` · `easements` · `roads` · `water` · `subdivisions` · `section_grid` · `special_districts` · `annotations` · `historic` · `LatLon_Table` · `grossarea` | — | mixed |
| `_Documentation.doc` · `_DOR_Code_Manual.docx` | — | 2023 / 2021 |

**The "more" is all GIS. There is no buildings table, no permits table, no owners table.** Hillsborough is **flat roll + sales + GIS layers** — the same class as Lee and Duval, not the same class as Pinellas, Pasco or Collier.

That removes 533,207 parcels (5.0% of the state) from the relational-depth column. It does not remove them from coverage — parcel and sales still land, weekly.

**Downgrade Hillsborough from the relational loader to the flat-roll path.** This is exactly the engineering threshold the work-list already wrote: *"if a probe reveals a county's bulk download is a single denormalized row-per-parcel file, downgrade it."* The probe has now revealed it.

### The postback, for when it's wanted anyway

Every file link is `javascript:__doPostBack('grdFiles$ctl00$ctlNN$ctl00','')`. That is ordinary WebForms and is automatable: GET the index, extract `__VIEWSTATE`, `__VIEWSTATEGENERATOR` and `__EVENTVALIDATION`, then POST with `__EVENTTARGET` set to the control id.

**The trap, and it is a real one.** `ctlNN` is **positional** — 04, 06, 08, 10 … incrementing by two down the listing. It is not bound to the file. Add or remove one file and every id below it shifts, and the loader silently pulls the wrong archive with no error. **Resolve the control id by matching the link text on each run. Never store it.** This is the `objectid`-hardcoding lesson in a new costume: probe the identifier, don't assume it.

Folder navigation is plain GET (`?subfolder=_building_footprints`) — only file retrieval needs the POST.

---

## 2. Collier — resolved, genuinely relational, filenames known

**Blocked as:** robots.

Relational structure is confirmed from the page itself, not inferred. Join keys are `PARCELID` and `ACCOUNTID`.

| table | file |
|---|---|
| Parcels | `int_parcels_csv.zip` |
| Buildings + extra features | `int_buildings_csv.zip` |
| Land | `int_land_csv.zip` |
| Sales history | `int_sales_csv.zip` |
| Legal descriptions | `int_legal_csv.zip` |
| TPP accounts | `int_accounts_csv.zip` |
| Real property values history (5 yr) | `int_values_rp_history_csv.zip` |
| TPP values history (5 yr) | `int_values_tp_history_csv.zip` |
| Millage rates (5 yr) | `int_millage_rates_csv.zip` |
| Taxing authorities history | `int_taxing_authorities_history_csv.zip` |
| CRA history | `int_cra_history_csv.zip` |
| **Everything, incl. lookups** | **`intfiles_csv.zip`** |
| Use codes | `int_usecodes_csv.zip` |
| Building codes | `int_buildingcodes_csv.zip` |
| Subdivision / condo ranges | `int_subcondos_csv.zip` |
| NAICS codes | `int_naics12_csv.zip` |
| Parcel polygons | `parcel_polygon_shape_file.zip` |
| Subdivision polygons | `subdivision_polygon_shape_file.zip` |

Take `intfiles_csv.zip` — one request, all tables, plus the code lookups. The lookups matter: `USECODE` and `BLDGCLASS` are coded and the crosswalk ships with them, which is the difference between a real use-code finding and an opaque `STATUS`-class sentinel.

**What Collier does not have:** no permits table and no separate owners table. Multi-owner may be flattened into `int_parcels`. **Verify owner cardinality on arrival** — Volusia measured 41.5% multi-owner, and a flattened source silently misrepresents that share.

**Cadence, stated on the page:** ownership current within about a month of recording; values updated twice a year — shortly after 1 July (preliminary) and around 1 November (final certified). Not weekly. `as_of` must carry that.

**Still needed:** one probe for the directory the filenames sit under. The page lists names, not full paths.

---

## 3. Palm Beach — resolved, all fourteen links, and a freshness problem

**Blocked as:** Nextcloud session. It is not a session — the links are public share tokens on `pbcclouddrive.pbcgov.org`.

| file | format | share token |
|---|---|---|
| **CAMA PAS405E** | standard | `6fa657a3d839e959d43e` |
| **CAMA PAS405E** | **CSV** | **`a25a521abeccea9b9f87`** |
| NAL-AA REC10 | standard / CSV | `bf30ed97c033173b3f10` / `e74d37367f4aa9b56d68` |
| NAL-AA REC20 | standard / CSV | `68bc24c066b0508fc898` / `e4b9507aa8ef6af76da3` |
| NAL-AA REC35 | standard / CSV | `569864c780d77c78dfad` / `ed0b808ccefc86236917` |
| NAL-AA REC36 | standard / CSV | `5e45098c94ae05837842` / `e6eac5212f9b377479b3` |
| NAL-AA REC40 | standard / CSV | `4ab7894184912dd251b1` / `8ddfbac1e2cfa6bb75ea` |
| DR-590 (12D8) | CSV | `2c0566b6cb9eb03e8423` |
| Tangible NAP (12D8) | CSV | `f716da4a71e958ed9502` |
| Situs | standard | `d19f613a302db903a2d3` |
| **All Ownership** | **CSV** | **`d0bebfe7f8e4037ae2e8`** |
| Vector | CSV | `5234367dd76d4642f874` |

Pattern: `https://pbcclouddrive.pbcgov.org/invitations/?share={token}&dl=0`

**The All Ownership file is the one to take first.** It carries non-confidential owner names per `PARID` — that is co-owner recovery for 659,119 parcels, the second county after Volusia where ownership can be modelled as a set rather than a single addressee.

**The Vector file** carries parcel, card, line, class, subarea description and vector string — building traverse geometry. Nothing else on the board has that outside Volusia.

### The freshness problem, stated plainly

Every row on that page reads **"Published in August and November — Last updated September 2025."** As of today that is roughly eleven months old, and the August 2026 publication either has not happened or has not been posted.

**Palm Beach CAMA is therefore no fresher than the DOR certified roll you already hold.** The gain from taking it is *structural* — eight record types per parcel, all-owners, traverse — not *temporal*. Do not let it win a precedence contest against a fresher source on the assumption that county beats state. Here it does not.

---

## 4. Miami-Dade — partially resolved, and the blocked part is the data

**Blocked as:** authenticated BBS. That is half right.

The `Main` library **is** publicly readable and holds three files, all documentation:

- `public files codes 2024_11.xlsx`
- `public+files+examples+23_01_27.xlsx` — sample tabs
- `readme+2026-02-20+-+property+appraiser.pdf`

Per-file URL pattern: `https://bbs.miamidadepa.gov/library/view/file/?lib=Main&file={urlencoded name}`

**The library index — `/library/list/libs/` — is robots-disallowed.** So the documentation is reachable and the list of data libraries is not. Miami-Dade stays open, but the blocker is now precise: one browser visit to enumerate library names, after which the `?lib=` parameter is very likely all that is needed.

Take the readme and the codes file first regardless. They are dated 2026-02-20 and 2024-11 and they answer the structural question the work-list flagged as unknown — whether Miami-Dade is relational or flat — without needing the data.

---

## 5. Board position after this

| county | parcels | category after probe | change |
|---|---|---|---|
| Pinellas | 432,360 | relational, 14 tables, nightly | unchanged — endpoint still unresolved |
| Pasco | 310,542 | relational, 11 tables, weekly | unchanged |
| Collier | 364,827 | **relational — confirmed, filenames known** | **resolved** |
| Palm Beach | 682,984 | **relational — resolved, but ~11 months stale** | **resolved with caveat** |
| Polk | 424,289 | relational, nightly, has permits | still needs FTP |
| **Hillsborough** | **533,207** | **flat roll + sales — DOWNGRADED** | **category corrected** |
| Miami-Dade | 585,220 | unknown | narrowed to one browser step |
| Lee / Duval | 954,163 | flat roll + sales (measured) | unchanged |
| Brevard | 347,497 | unknown, Access-only | unchanged |
| Broward / Orange | 1,254,000 | paid / physical media | unchanged |

**Relational depth now confirmed reachable and free:** Volusia + Pasco + Collier + Palm Beach + Polk + Pinellas ≈ **2.5M parcels, roughly 23% of the state** — but only three of those six have both a resolved endpoint and a usable cadence today.

**Only two counties on the entire board publish a permits table** — Polk and Pinellas — and neither endpoint is resolved. Permits are what the addressfolder is built on and what the marine-improvement cross-examination runs against. That makes Polk's FTP and the Pinellas network capture worth more than their parcel counts suggest, and it is a sharper argument for doing both than "they're the biggest analogues."

---

## 6. Still unresolved

- **Pinellas** — JS download controls; DevTools capture outstanding.
- **Polk** — TLS FTP at `ftp.polkflpa.gov`; needs an FTP client, not a fetch.
- **Miami-Dade** — one browser visit to `/library/list/libs/`.
- **Brevard** — `WebData.zip` internal structure; only answerable by downloading it.
- **Collier** — directory path for the `int_*` filenames.
- **Broward, Orange** — procurement, unchanged. Prices genuinely not published.
- **Row counts, everywhere.** Not measured, not estimated.
