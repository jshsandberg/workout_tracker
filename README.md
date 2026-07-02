Exercise Naming Rules

- IDs never change once created.
- If a variation significantly changes loading or progression, create a new exercise ID.
- If no variation is specified, assume the standard version.

Examples:
- weighted_pullup = pronated
- weighted_chinup = supinated
- weighted_neutral_pullup = neutral grip
- incline_bench = barbell
- chest_supported_db_row = dumbbells
- barbell_shrug = performed with straps

Workout Logging Rules

- Preserve the order exercises were performed.
- Set `location` to a short stable place ID, such as `home` or `planet_fitness`.
- For supersets, set `superset` to the ID of the exercise this movement was paired with.
- For paired supersets, each exercise should reference the other exercise's ID.

Project Log

- 2026-07-02: Added workout location tracking, added superset tracking by paired exercise ID, created today's `planet_fitness` workout log, and added the exercises from today's workout image using existing exercise IDs.
