Exercise Naming Rules

- IDs never change once created.
- If a variation significantly changes loading or progression, create a new exercise ID.
- If no variation is specified, assume the standard version.

Examples:
- pullup = pronated; use `added_weight` for bodyweight, weighted, or assisted loading
- weighted_chinup = supinated
- weighted_neutral_pullup = neutral grip
- dip = standard dip; use `added_weight` for bodyweight, weighted, or assisted loading
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

Project Log

- 2026-07-02: Added workout location tracking, added superset tracking by paired exercise ID, created today's `planet_fitness` workout log, and added the exercises from today's workout image using existing exercise IDs.
