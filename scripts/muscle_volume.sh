#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 0 ]]; then
  echo "Usage: scripts/muscle_volume.sh" >&2
  exit 1
fi

command -v jq >/dev/null 2>&1 || { echo "error: jq is required" >&2; exit 1; }

if [[ ! -t 0 ]]; then
  echo "error: muscle_volume.sh requires an interactive terminal" >&2
  exit 1
fi

end_date="$(date +%F)"

echo "Select a volume timeline:"
echo
echo "  1) Previous 7 days"
echo "  2) Previous 14 days"
echo "  3) Previous month (30 days)"
echo "  4) Previous 3 months (90 days)"
echo "  5) All time"
echo

while true; do
  read -r -p "Choice (1-5, or q to quit): " choice
  case "$choice" in
    1) days=7; period_label="Previous 7 days"; break ;;
    2) days=14; period_label="Previous 14 days"; break ;;
    3) days=30; period_label="Previous month (30 days)"; break ;;
    4) days=90; period_label="Previous 3 months (90 days)"; break ;;
    5) days=0; period_label="All time"; break ;;
    q|Q) exit 0 ;;
    *) echo "Please enter a number from 1 to 5." ;;
  esac
done

echo
echo "Select muscle columns:"
echo
echo "  1) Primary muscles only"
echo "  2) Primary and secondary muscles"
echo

while true; do
  read -r -p "Choice (1-2, or q to quit): " choice
  case "$choice" in
    1) show_secondary=false; break ;;
    2) show_secondary=true; break ;;
    q|Q) exit 0 ;;
    *) echo "Please enter 1 or 2." ;;
  esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
exercises_file="$repo_root/data/exercises.json"
muscles_file="$repo_root/data/muscles.json"

shopt -s nullglob
workout_files=("$repo_root"/data/workouts/*.json)
if [[ ${#workout_files[@]} -eq 0 ]]; then
  echo "No workouts found."
  exit 0
fi

echo
echo "$period_label, ending $end_date"

jq -s -r \
  --arg end_date "$end_date" \
  --argjson days "$days" \
  --argjson show_secondary "$show_secondary" '
    . as $docs
    | ($docs[0]) as $catalog
    | ($docs[1]) as $muscles
    | ($end_date + "T00:00:00Z" | fromdateiso8601) as $end
    | (if $days == 0 then 0 else $end - (($days - 1) * 86400) end) as $start
    | [
        $docs[2:][]
        | select(.date <= $end_date)
        | select($days == 0 or ((.date + "T00:00:00Z" | fromdateiso8601) >= $start))
        | (.exercises // [])[]
        | . as $exercise
        | ([($exercise.sets // [])[] | select((.reps // 0) > 0)] | length) as $set_count
        | select($set_count > 0)
        | ($catalog[$exercise.id].muscles // {primary: [], secondary: []}) as $targets
        | ($targets.primary[]? | {muscle: ., type: "primary", sets: $set_count}),
          ($targets.secondary[]? | {muscle: ., type: "secondary", sets: $set_count})
      ] as $credits
    | [
        $credits[].muscle
      ]
      | unique
      | map(
          . as $muscle
          | {
              name: ($muscles[$muscle].name // $muscle),
              primary: ([$credits[] | select(.muscle == $muscle and .type == "primary") | .sets] | add // 0),
              secondary: ([$credits[] | select(.muscle == $muscle and .type == "secondary") | .sets] | add // 0)
            }
        )
      | map(select(.primary > 0 or ($show_secondary and .secondary > 0)))
      | if $show_secondary then
          sort_by(-.primary, -.secondary, .name)
        else
          sort_by(-.primary, .name)
        end
      | if length == 0 then
          "No completed sets found in this period."
        elif $show_secondary then
          (["Muscle", "Primary sets", "Secondary sets"],
           (.[] | [.name, (.primary | tostring), (.secondary | tostring)]))
          | @tsv
        else
          (["Muscle", "Primary sets"],
           (.[] | [.name, (.primary | tostring)]))
          | @tsv
        end
  ' "$exercises_file" "$muscles_file" "${workout_files[@]}" \
  | if command -v column >/dev/null 2>&1; then column -t -s $'\t'; else cat; fi
