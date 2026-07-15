#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 0 ]]; then
  echo "Usage: scripts/muscle_volume_trend.sh" >&2
  exit 1
fi

command -v jq >/dev/null 2>&1 || { echo "error: jq is required" >&2; exit 1; }

if [[ ! -t 0 ]]; then
  echo "error: muscle_volume_trend.sh requires an interactive terminal" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
exercises_file="$repo_root/data/exercises.json"
muscles_file="$repo_root/data/muscles.json"
end_date="$(date +%F)"

shopt -s nullglob
workout_files=("$repo_root"/data/workouts/*.json)
if [[ ${#workout_files[@]} -eq 0 ]]; then
  echo "No workouts found."
  exit 0
fi

earliest_date="$(jq -s -r '[.[].date] | min' "${workout_files[@]}")"
all_weeks="$(
  jq -n -r \
    --arg earliest "$earliest_date" \
    --arg end_date "$end_date" '
      ($earliest + "T00:00:00Z" | fromdateiso8601) as $start
      | ($end_date + "T00:00:00Z" | fromdateiso8601) as $end
      | (((($end - $start) / 86400 | floor) + 7) / 7 | floor)
    '
)"

if [[ "$all_weeks" -lt 1 ]]; then
  all_weeks=1
fi

echo "How many rolling weeks should be compared?"
echo
echo "  1) 3 weeks"
echo "  2) 4 weeks"
echo "  3) 8 weeks"
echo "  4) 12 weeks"
echo "  5) All recorded weeks ($all_weeks)"
echo "  6) Custom"
echo

while true; do
  read -r -p "Choice (1-6, or q to quit): " choice
  case "$choice" in
    1) week_count=3; break ;;
    2) week_count=4; break ;;
    3) week_count=8; break ;;
    4) week_count=12; break ;;
    5) week_count="$all_weeks"; break ;;
    6)
      while true; do
        read -r -p "Number of weeks: " custom_weeks
        if [[ "$custom_weeks" =~ ^[1-9][0-9]*$ ]]; then
          week_count="$custom_weeks"
          break 2
        fi
        echo "Please enter a positive whole number."
      done
      ;;
    q|Q) exit 0 ;;
    *) echo "Please enter a number from 1 to 6." ;;
  esac
done

echo
echo "Muscle volume trend"
echo "Each row is one muscle in one non-overlapping 7-day period."
echo

jq -n -r \
  --arg end_date "$end_date" \
  --argjson week_count "$week_count" '
    ($end_date + "T00:00:00Z" | fromdateiso8601) as $end
    | range($week_count - 1; -1; -1) as $age
    | ($end - ($age * 7 * 86400)) as $week_end
    | ($week_end - (6 * 86400)) as $week_start
    | (if $age == 0 then "Current"
       elif $age == 1 then "1 week ago"
       else (($age | tostring) + " weeks ago")
       end) as $label
    | "  \($label): \($week_start | strftime("%Y-%m-%d")) to \($week_end | strftime("%Y-%m-%d"))"
  '

echo

jq -s -r \
  --arg end_date "$end_date" \
  --argjson week_count "$week_count" '
    def rounded_tenth:
      (. * 10 | round) / 10;

    def period_label($age):
      if $age == 0 then "Current"
      elif $age == 1 then "1 week ago"
      else (($age | tostring) + " weeks ago")
      end;

    def percent_display:
      . as $change
      | (if $change > 0 then "+" else "" end)
        + ($change | tostring)
        + (if ($change | floor) == $change then ".0%" else "%" end);

    def comma_number:
      (round | tostring) as $text
      | ($text | length) as $length
      | if $length <= 3 then
          $text
        else
          ($length % 3) as $remainder
          | (if $remainder == 0 then 3 else $remainder end) as $head_length
          | $text[0:$head_length]
            + ([range($head_length; $length; 3) as $index
                | "," + $text[$index:($index + 3)]] | join(""))
        end;

    def change_value($current; $previous; $valid):
      if ($valid | not) or $previous == null or $current == null or $previous <= 0 then
        null
      else
        ((($current - $previous) / $previous) * 100 | rounded_tenth)
      end;

    def change_display($current; $previous; $valid):
      if ($valid | not) or $previous == null or $current == null then
        "—"
      elif $previous == 0 and $current > 0 then
        "NEW"
      elif $previous <= 0 then
        "—"
      else
        (change_value($current; $previous; true) | percent_display)
      end;

    . as $docs
    | ($docs[0]) as $catalog
    | ($docs[1]) as $muscles
    | ($end_date + "T00:00:00Z" | fromdateiso8601) as $end
    | ($end - (($week_count * 7 - 1) * 86400)) as $history_start
    | [
        $catalog
        | to_entries[]
        | select((.value.volume_mode // "external_weight") != "ignore")
        | .value.muscles.primary[]?
      ]
      | unique as $muscle_ids
    | [
        $docs[2:][]
        | . as $workout
        | ($workout.date + "T00:00:00Z" | fromdateiso8601) as $workout_date
        | select($workout_date >= $history_start and $workout_date <= $end)
        | (($end - $workout_date) / (7 * 86400) | floor) as $week_age
        | (.exercises // [])[]
        | . as $exercise
        | ($catalog[$exercise.id] // {}) as $definition
        | [($exercise.sets // [])[] | select((.reps // 0) > 0)] as $sets
        | select($sets | length > 0)
        | ($definition.uses_bodyweight // false) as $uses_bodyweight
        | ($definition.volume_mode //
            (if $uses_bodyweight then "bodyweight_plus_external" else "external_weight" end)
          ) as $volume_mode
        | select($volume_mode != "ignore")
        | ($definition.load_multiplier // 1) as $multiplier
        | (if $volume_mode == "reps_only" or $volume_mode == "sets_only" then
             null
           elif $volume_mode == "bodyweight_plus_external"
                and ($workout.bodyweight == null or any($sets[]; .weight == null)) then
             null
           elif $volume_mode == "bodyweight_plus_external" then
             ([$sets[] | (($workout.bodyweight + .weight) * .reps * $multiplier)] | add // 0 | round)
           elif any($sets[]; .weight == null) then
             null
           else
             ([$sets[] | .weight * .reps * $multiplier] | add // 0 | round)
           end) as $weighted_volume
        | $definition.muscles.primary[]?
        | {
            muscle: .,
            week_age: $week_age,
            sets: ($sets | length),
            reps: ([$sets[].reps] | add // 0),
            weighted_volume: $weighted_volume,
            missing: (($volume_mode != "reps_only" and $volume_mode != "sets_only") and $weighted_volume == null)
          }
      ] as $credits
    | [
        $muscle_ids[] as $muscle
        | ([
            $catalog
            | to_entries[]
            | select(any(.value.muscles.primary[]?; . == $muscle))
            | (.value.volume_mode //
                (if (.value.uses_bodyweight // false) then "bodyweight_plus_external" else "external_weight" end)
              )
            | select(. != "reps_only" and . != "sets_only" and . != "ignore")
          ] | length > 0) as $uses_weighted_volume
        | [
            range($week_count - 1; -1; -1) as $age
            | [$credits[] | select(.muscle == $muscle and .week_age == $age)] as $week_credits
            | ([$week_credits[].sets] | add // 0) as $sets
            | any($week_credits[]; .missing) as $missing
            | (if $uses_weighted_volume then
                 ([$week_credits[] | select(.weighted_volume != null) | .weighted_volume] | add // 0)
               else
                 ([$week_credits[].reps] | add // 0)
               end) as $value
            | {
                age: $age,
                value: $value,
                sets: $sets,
                partial: $missing,
                valid: ($missing | not),
                per_set: (if $sets > 0 then ($value / $sets) else null end),
                display: (
                  ($value | tostring)
                  + (if $missing then "*" else "" end)
                  + " / "
                  + ($sets | tostring)
                )
              }
          ] as $weeks
        | ($weeks | length) as $week_length
        | $weeks[-1] as $latest
        | (if $week_length >= 2 then $weeks[-2] else null end) as $previous
        | (($previous != null) and $latest.valid and ($previous.valid // false)) as $latest_comparable
        | change_value($latest.value; ($previous.value // null); $latest_comparable) as $latest_change
        | change_value($latest.per_set; ($previous.per_set // null); $latest_comparable) as $per_set_change
        | [
            range(0; $week_length) as $index
            | select($weeks[$index].valid and $weeks[$index].value > 0)
            | {index: $index, value: $weeks[$index].value}
          ] as $positive_points
        | (if ($positive_points | length) >= 2 and $positive_points[-1].index == ($week_length - 1) then
             $positive_points[0]
           else null
           end) as $first_point
        | (if $first_point != null then $positive_points[-1] else null end) as $last_point
        | (if $first_point == null then false
           else all(
             range($first_point.index; $last_point.index + 1);
             $weeks[.].valid and $weeks[.].value > 0
           )
           end) as $continuous
        | (if $continuous then ($last_point.index - $first_point.index) else 0 end) as $growth_intervals
        | (if $growth_intervals >= 1 then
             ((pow(($last_point.value / $first_point.value); (1 / $growth_intervals)) - 1) * 100 | rounded_tenth)
           else null
           end) as $weekly_growth
        | (if $continuous then ($growth_intervals + 1) else 0 end) as $trend_weeks
        | {
            muscle: ($muscles[$muscle].name // $muscle),
            metric: (if $uses_weighted_volume then "lb-reps" else "reps" end),
            weeks: $weeks,
            latest_change: change_display($latest.value; ($previous.value // null); $latest_comparable),
            per_set_change: change_display($latest.per_set; ($previous.per_set // null); $latest_comparable),
            weekly_growth: (if $weekly_growth == null then "—" else ($weekly_growth | percent_display) end),
            status: (
              if $latest.partial or ($previous.partial // false) then "PARTIAL"
              elif $previous == null then "INSUFFICIENT DATA"
              elif $previous.value == 0 and $latest.value > 0 then "NEW"
              elif $latest_change != null and $per_set_change != null and ($latest_change * $per_set_change) < 0 then "MIXED"
              elif $trend_weeks >= 4 and $weekly_growth > 0 then "TRENDING UP"
              elif $trend_weeks >= 4 and $weekly_growth < 0 then "TRENDING DOWN"
              elif $trend_weeks >= 4 then "STABLE"
              elif $latest_change > 0 then "UP"
              elif $latest_change < 0 then "DOWN"
              elif $latest_change == 0 then "STABLE"
              else "INSUFFICIENT DATA"
              end
            )
          }
      ]
    | sort_by(.muscle | ascii_downcase) as $results
    | (["Muscle", "Week", "Total volume", "Sets", "Volume/set", "Latest Δ", "Vol/set Δ", "Weekly CAGR", "Status"],
       ($results[]
        | . as $result
        | .weeks[]
        | [
            $result.muscle,
            period_label(.age),
            ((.value | comma_number)
             + (if .partial then "*" else "" end)
             + " " + $result.metric),
            (.sets | tostring),
            (if .per_set == null then "—"
             else ((.per_set | comma_number)
                   + (if $result.metric == "lb-reps" then " lb/set" else " reps/set" end))
             end),
            (if .age == 0 then $result.latest_change else "—" end),
            (if .age == 0 then $result.per_set_change else "—" end),
            (if .age == 0 then $result.weekly_growth else "—" end),
            (if .age == 0 then $result.status else "—" end)
          ]))
    | @tsv
  ' "$exercises_file" "$muscles_file" "${workout_files[@]}" \
  | if command -v column >/dev/null 2>&1; then column -t -s $'\t'; else cat; fi

echo
echo "Trend columns are populated on each muscle's Current row."
echo "Latest Δ compares current total volume with the immediately preceding week."
echo "Vol/set Δ compares current average volume per working set with the preceding week."
echo "Weekly CAGR is compound growth from the first continuous positive week through the current week."
echo "UP/DOWN describes one comparison; TRENDING UP/DOWN requires at least four continuous valid weeks."
echo "An asterisk preserves known volume while marking a week with missing load data."
echo "Bodyweight movements use logged workout bodyweight plus added load."
echo "Volume is credited in full to each primary muscle and describes workload, not guaranteed strength or growth."
