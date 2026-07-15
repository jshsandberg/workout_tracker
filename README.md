Exercise Naming Rules

- IDs never change once created.
- If a variation significantly changes loading or progression, create a new exercise ID.
- If no variation is specified, assume the standard version.

Examples:
- pullup = pronated; record added or assisted load as `weight` on every set
- weighted_chinup = supinated
- weighted_neutral_pullup = neutral grip
- dip = standard dip; record added or assisted load as `weight` on every set
- decline_ab_crunch = record added load as `weight` on every set; use `0` for bodyweight
- incline_bench = barbell
- chest_supported_db_row = dumbbells
- barbell_shrug = performed with straps

Workout Logging Rules

- Preserve the order exercises were performed.
- Set `location` to a short stable place ID, such as `home` or `planet_fitness`.
- For supersets, set `superset` to the ID of the exercise this movement was paired with.
- For paired supersets, each exercise should reference the other exercise's ID.

Adding A New Workout

1. Create a new file in `data/workouts/` using `YYYY-MM-DD_###.json`.
   - Use `_001` for the first workout that day.
   - Use `_002`, `_003`, and so on only if there are multiple workouts on the same date.
2. Set the top-level workout details.
   - `date`: workout date in `YYYY-MM-DD` format.
   - `session`: session number for that date.
   - `location`: short stable place ID.
   - `bodyweight`: bodyweight in lb, if known.
   - `calories`, `protein`, and `recovery`: fill in if known, otherwise use `null`.
   - `notes`: optional plain-language notes about the workout.
3. Add exercises in the exact order performed.
   - Use an existing exercise ID from `data/exercises.json` whenever possible.
   - If an exercise does not exist in `data/exercises.json`, add it there before logging it in the workout.
   - When adding a new exercise, include `name`, `uses_bodyweight`, and `muscles.primary` / `muscles.secondary`.
   - Set `volume_mode` when the default weight × reps calculation is not appropriate, especially for bodyweight exercises.
   - Use `volume_mode: "ignore"` for isometric holds, carries, or any movement that should contribute neither volume nor sets to the muscle trend report.
   - Set `load_multiplier` when the logged load represents one side or one dumbbell but both sides contribute to the completed set. For example, use `2` for two-dumbbell rows logged with per-dumbbell weight.
   - After adding new exercises, report the exact exercise IDs, display names, bodyweight setting, primary muscles, and secondary muscles so they can be confirmed.
   - If a movement is meaningfully different for loading or progression, add a new stable ID instead of reusing a close-but-different exercise.
   - `uses_bodyweight` comes from `data/exercises.json`; do not duplicate it in workout exercise entries. Include `weight` on every bodyweight set: `0` for bodyweight-only, a positive value for added load, and a negative value for assistance.
   - Never use exercise-level `added_weight`; bodyweight loading belongs on each set even when every set uses the same load.
   - For supersets, set each exercise's `superset` value to the paired exercise ID.
4. Add each set with the reps performed.
   - Include `weight` for loaded movements.
   - For bodyweight movements, per-set `weight` is required and represents only added or assisted load, not total system weight.
   - Keep failed reps, partial notes, or unusual details in `notes` if they do not fit the normal set shape.
5. After entering the workout, check that every exercise ID exists in `data/exercises.json` and that the JSON is valid.

Workout Template

```json
{
  "date": "YYYY-MM-DD",
  "session": 1,
  "location": "home",
  "bodyweight": null,
  "calories": null,
  "protein": null,
  "recovery": null,
  "notes": "",
  "exercises": [
    {
      "id": "exercise_id",
      "sets": [
        {
          "weight": 100,
          "reps": 10
        }
      ]
    }
  ]
}
```

Muscle Volume Trend Script

`scripts/muscle_volume_trend.sh` is the single reporting script. Run it without
flags and choose how many rolling weeks to compare in the console.

```bash
scripts/muscle_volume_trend.sh
```

The report has one database-style row per muscle per week, with separate
total-volume, working-set, and volume-per-set columns. Each muscle's current row
also shows the latest total-volume change, latest volume-per-set change, compound
weekly growth rate, and status. Numeric workload values include thousands
separators for readability.

Loaded movements use external weight × reps. Bodyweight movements use the
workout's logged bodyweight plus per-set weight, so a
bodyweight decline crunch at 190 lb uses 190 lb as its load. `load_multiplier`
adjusts per-dumbbell or per-side entries; two 70 lb dumbbells therefore count as
140 lb of external load.

Volume is credited in full to every primary muscle assigned to an exercise.
Loads from different movements and machines are not mechanically identical, so
the report describes tracked workload rather than guaranteed strength or growth.

`Weekly CAGR` is compound growth from the first continuous positive week through
the current week; percentages are never arithmetically averaged. `UP` and `DOWN`
describe a single comparison, while `TRENDING UP` and `TRENDING DOWN` require at
least four continuous valid weeks. Opposing total-volume and volume-per-set
directions are labeled `MIXED`.

Known volume is retained with an asterisk when some load data is missing. Any
exercise with `volume_mode: "ignore"` is excluded completely from the report,
including both volume and working sets. Farmer walks currently use this mode
because their logged reps represent carry distance rather than repetitions
comparable to a lift.

Project Log

- 2026-07-02: Added workout location tracking, added superset tracking by paired exercise ID, created today's `planet_fitness` workout log, and added the exercises from today's workout image using existing exercise IDs.
