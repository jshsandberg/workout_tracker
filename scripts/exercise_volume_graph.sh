#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 0 ]]; then
  echo "Usage: scripts/exercise_volume_graph.sh" >&2
  exit 1
fi

command -v jq >/dev/null 2>&1 || { echo "error: jq is required" >&2; exit 1; }

if [[ ! -t 0 ]]; then
  echo "error: exercise_volume_graph.sh requires an interactive terminal" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
exercises_file="$repo_root/data/exercises.json"

shopt -s nullglob
workout_files=("$repo_root"/data/workouts/*.json)
if [[ ${#workout_files[@]} -eq 0 ]]; then
  echo "No workouts found."
  exit 0
fi

exercise_ids=()
exercise_names=()
while IFS=$'\t' read -r exercise_id exercise_name; do
  exercise_ids+=("$exercise_id")
  exercise_names+=("$exercise_name")
done < <(
  jq -s -r '
    . as $docs
    | ($docs[0]) as $catalog
    | [$docs[1:][] | (.exercises // [])[] | .id]
    | unique
    | map({id: ., name: ($catalog[.].name // .)})
    | sort_by(.name | ascii_downcase)
    | .[]
    | [.id, .name]
    | @tsv
  ' "$exercises_file" "${workout_files[@]}"
)

if [[ ${#exercise_ids[@]} -eq 0 ]]; then
  echo "No exercises found in workout history."
  exit 0
fi

echo "Select an exercise:"
echo
for i in "${!exercise_names[@]}"; do
  printf '%3d) %s\n' "$((i + 1))" "${exercise_names[$i]}"
done
echo

while true; do
  read -r -p "Choice (1-${#exercise_ids[@]}, or q to quit): " choice
  if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
    exit 0
  fi
  if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#exercise_ids[@]})); then
    selected_id="${exercise_ids[$((choice - 1))]}"
    selected_name="${exercise_names[$((choice - 1))]}"
    break
  fi
  echo "Please enter a number from 1 to ${#exercise_ids[@]}."
done

rows=()
while IFS= read -r row; do
  rows+=("$row")
done < <(
  jq -s -r \
    --arg exercise_id "$selected_id" '
      . as $docs
      | [
          $docs[1:][]
          | . as $workout
          | (.exercises // [])[]
          | select(.id == $exercise_id)
          | . as $exercise
          | [($exercise.sets // [])[] | select((.reps // 0) > 0)] as $sets
          | select($sets | length > 0)
          | ($exercise.bodyweight // false) as $uses_bodyweight
          | {
              date: $workout.date,
              session: ($workout.session // 1),
              sets: ($sets | length),
              reps: ([$sets[].reps] | add // 0),
              missing_load: (
                if $uses_bodyweight then
                  ($workout.bodyweight == null)
                else
                  any($sets[]; .weight == null)
                end
              ),
              volume: ((
                if $uses_bodyweight and $workout.bodyweight == null then
                  null
                elif $uses_bodyweight then
                  [$sets[]
                    | ((.weight // $exercise.added_weight // 0) + $workout.bodyweight) * .reps
                  ] | add // 0
                elif any($sets[]; .weight == null) then
                  null
                else
                  [$sets[] | .weight * .reps] | add // 0
                end
              ) | if . == null then null else round end)
            }
        ]
      | sort_by(.date, .session)
      | .[]
      | [.date, (.session | tostring), (.sets | tostring), (.reps | tostring),
         (if .volume == null then "NA" else (.volume | tostring) end)]
      | @tsv
    ' "$exercises_file" "${workout_files[@]}"
)

if [[ ${#rows[@]} -eq 0 ]]; then
  echo
  echo "No completed sets found for $selected_name."
  exit 0
fi

max_volume=0
for row in "${rows[@]}"; do
  IFS=$'\t' read -r _ _ _ _ volume <<< "$row"
  if [[ "$volume" != "NA" ]] && ((volume > max_volume)); then
    max_volume=$volume
  fi
done

bar_width=40
echo
echo "$selected_name — session volume"
echo "Volume = sum of weight × reps (lb-reps)"
echo

for row in "${rows[@]}"; do
  IFS=$'\t' read -r date session sets reps volume <<< "$row"
  label="$date"
  if ((session > 1)); then
    label="$date #$session"
  fi

  if [[ "$volume" == "NA" ]]; then
    printf '%-13s  %-40s  volume N/A  (%s sets, %s reps)\n' \
      "$label" "" "$sets" "$reps"
    continue
  fi

  if ((max_volume > 0 && volume > 0)); then
    bar_length=$(((volume * bar_width + max_volume - 1) / max_volume))
  else
    bar_length=0
  fi
  bar=""
  if ((bar_length > 0)); then
    printf -v bar '%*s' "$bar_length" ''
    bar=${bar// /#}
  fi

  printf '%-13s  %-40s  %8d lb-reps  (%s sets, %s reps)\n' \
    "$label" "$bar" "$volume" "$sets" "$reps"
done

echo
echo "Bodyweight exercise volume includes logged bodyweight plus per-set added weight."
echo "Sessions without enough load information are shown as volume N/A."
