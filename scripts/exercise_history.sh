#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/exercise_history.sh [--limit N] [EXERCISE_QUERY]

Examples:
  scripts/exercise_history.sh bench
  scripts/exercise_history.sh --limit 5 "db pullover"
  scripts/exercise_history.sh

Searches exercise IDs and display names, then prints the most recent matching
workouts with each set's weight and reps. If no query is provided, the script
shows an interactive numbered exercise list.
EOF
}

limit=10
query=""
exact_match=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -n|--limit)
      if [[ $# -lt 2 || ! "$2" =~ ^[0-9]+$ || "$2" -eq 0 ]]; then
        echo "error: --limit requires a positive integer" >&2
        exit 1
      fi
      limit="$2"
      shift 2
      ;;
    --)
      shift
      query="$*"
      break
      ;;
    -*)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "$query" ]]; then
        query="$query $1"
      else
        query="$1"
      fi
      shift
      ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required to run this script" >&2
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

if [[ -z "$query" ]]; then
  if [[ ! -t 0 ]]; then
    echo "error: exercise query is required when not running interactively" >&2
    usage >&2
    exit 1
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
      query="${exercise_ids[$((choice - 1))]}"
      exact_match=true
      echo
      break
    fi
    echo "Please enter a number from 1 to ${#exercise_ids[@]}."
  done
fi

jq -s \
  -r \
  --arg query "$query" \
  --argjson exact_match "$exact_match" \
  --argjson limit "$limit" \
  '
  def norm: ascii_downcase;
  def matches_query($query; $id; $name):
    if $exact_match then
      $id == $query
    else
      ($id | norm | contains($query))
      or ($name | norm | contains($query))
    end;

  . as $docs
  | ($docs[0]) as $catalog
  | [
      $docs[1:][]
      | . as $workout
      | ($workout.exercises // [])[]
      | . as $exercise
      | ($catalog[$exercise.id].name // $exercise.id) as $exercise_name
      | select(matches_query(($query | norm); $exercise.id; $exercise_name))
      | {
          date: $workout.date,
          session: $workout.session,
          location: $workout.location,
          exercise_id: $exercise.id,
          exercise_name: $exercise_name,
          bodyweight: ($exercise.bodyweight // false),
          added_weight: ($exercise.added_weight // null),
          sets: [
            ($exercise.sets // [])[]
            | {
                weight: (.weight // null),
                reps: (.reps // null)
              }
          ]
        }
    ]
  | sort_by(.date, .session)
  | reverse
  | .[:$limit]
  | if length == 0 then
      "No matching exercise history found."
    else
      map(
        . as $entry |
        "\(.date)  \(.exercise_name)" +
        (if .session == null then "" else " (session \(.session))" end) +
        "\n" +
        ([.sets | to_entries[] |
          "  Set \(.key + 1): " +
          (if .value.reps == null then "? reps" else "\(.value.reps) reps" end) +
          (if .value.weight != null then " @ \(.value.weight) lb"
           elif $entry.bodyweight then " @ bodyweight"
           else " (no weight recorded)" end)
        ] | join("\n"))
      )
      | join("\n\n")
    end
  ' "$exercises_file" "${workout_files[@]}"
