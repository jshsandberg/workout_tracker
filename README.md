Exercise Naming Rules

- IDs never change once created.
- If a variation significantly changes loading or progression, create a new exercise ID.
- If no variation is specified, assume the standard version.

Examples:
- pullup = pronated; record added or assisted load as `weight` on every set
- weighted_chinup = supinated
- weighted_neutral_pullup = neutral grip
- dip = standard dip; record added or assisted load as `weight` on every set
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
   - After adding new exercises, report the exact exercise IDs, display names, bodyweight setting, primary muscles, and secondary muscles so they can be confirmed.
   - If a movement is meaningfully different for loading or progression, add a new stable ID instead of reusing a close-but-different exercise.
   - For bodyweight movements, set `bodyweight` to `true` and use `added_weight` for the external load: `0` for bodyweight-only, `10` for 10 lb added, and so on.
   - Exception: for all pull-up, chin-up, and dip variations, omit exercise-level `added_weight` and include `weight` on every set because loading may change between sets. Use `0` for bodyweight-only, a positive value for added weight, and a negative value for assistance.
   - For supersets, set each exercise's `superset` value to the paired exercise ID.
4. Add each set with the reps performed.
   - Include `weight` for loaded movements.
   - For bodyweight movements, omit per-set `weight` unless the set itself has a specific external load that differs from `added_weight`.
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

Exercise History Script

Use `scripts/exercise_history.sh` to look up recent history for an exercise by
ID or display name. It prints JSON and returns the 10 most recent matching
exercise entries by default.

```bash
scripts/exercise_history.sh bench
scripts/exercise_history.sh --limit 5 "db pullover"
```

Muscle Volume Script

Use `scripts/muscle_volume.sh` to total completed working sets by muscle over a
rolling timeline. The interactive mode asks for a period and whether secondary
muscle volume should appear in its own column.

```bash
scripts/muscle_volume.sh
```

Each recorded set with more than zero reps counts once toward every primary
muscle assigned to the exercise. Secondary sets use the same rule but are kept
separate from primary volume.

Exercise Volume Graph Script

Use `scripts/exercise_volume_graph.sh` to select an exercise and display an
ASCII graph of session volume. Each bar represents the sum of `weight × reps`
for that workout, with set and rep totals shown alongside it.

```bash
scripts/exercise_volume_graph.sh
```

For bodyweight exercises, volume includes the workout's logged bodyweight plus
per-set added weight. Sessions missing required load data are shown as `N/A`.

Project Log

- 2026-07-02: Added workout location tracking, added superset tracking by paired exercise ID, created today's `planet_fitness` workout log, and added the exercises from today's workout image using existing exercise IDs.
