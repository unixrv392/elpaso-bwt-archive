# El Paso Border Wait Times Archive

Git-scraper that polls the [CBP Border Wait Times API](https://bwt.cbp.gov/api/waittimes)
every 10 minutes and archives every **distinct** reading for the El Paso ports of entry:

| Port number | Crossing |
|---|---|
| 240201 | Bridge of the Americas (BOTA) |
| 240202 | Paso Del Norte (PDN) |
| 240203 | Ysleta |
| 240204 | Stanton DCL |
| 240221 | El Paso (port office record, usually "Update Pending") |

## Layout

- `latest.json` — snapshot of the most recent fetch (all El Paso ports), with a
  top-level `fetched_at` (UTC).
- `data/YYYY/MM/YYYY-MM-DD.ndjson` — the archive. One JSON line per distinct port
  reading: the full CBP port object plus `fetched_at` (UTC, time the change was
  first observed). Days are split by UTC date.
- `state/<port_number>.json` — last seen reading per port (minus the feed's own
  generation timestamp), used for change detection. Not interesting on its own.

A reading is archived when anything other than the feed's generation timestamp
(top-level `date`/`time`) changes: delay minutes, lanes open, operational status,
per-lane `update_time`, port status, hours, or construction notice. CBP updates
roughly hourly, so expect a few dozen lines per day, not 144.

## Purpose

Builds a measured wait-by-hour-by-weekday profile per crossing (delay, lanes open,
staleness) to calibrate the ETA model of an El Paso border-crossing app — replacing
hand-tuned constants with data. All content here is public CBP data.

## Notes

- Timestamps inside the CBP objects (`update_time`, `date`, `time`) are the feed's
  own, in local port time (MDT/MST); `fetched_at` is added by the scraper in UTC.
- The API is undocumented and unversioned; the workflow fails loudly (red run) if
  the response stops parsing or the El Paso ports disappear.
- Run `./scrape.sh` locally to test; it appends to the same layout.
