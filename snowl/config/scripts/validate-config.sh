#!/usr/bin/env bash
# Validate JSON syntax and cross-reference integrity for snowl-config.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required but not installed" >&2
  exit 1
fi

errors=0
warnings=0

fail() {
  echo "error: $*" >&2
  errors=$((errors + 1))
}

warn() {
  echo "warning: $*" >&2
  warnings=$((warnings + 1))
}

is_empty_json() {
  [[ "$(jq 'length' "$1")" -eq 0 ]]
}

echo "Validating JSON syntax..."
while IFS= read -r file; do
  [[ -n "${file}" ]] || continue
  if ! jq empty "${file}" 2>/dev/null; then
    echo "error: invalid JSON in ${file}" >&2
    jq empty "${file}" 2>&1 | sed 's/^/  /' >&2 || true
    errors=$((errors + 1))
  fi
done < <(git ls-files '*.json')

if [[ "${errors}" -gt 0 ]]; then
  echo "Validation failed with ${errors} error(s)." >&2
  exit 1
fi

echo "Validating cross-references..."

mapfile -t room_names < <(jq -r '.[].name' rooms.json | sort -u)
mapfile -t camera_ids < <(jq -r '.[].id' cameras.json | sort -n -u)
mapfile -t lens_names < <(jq -r '.[].name' lenses.json | sort -u)
mapfile -t pulpo_session_ids < <(jq -r '.sessions[].id' pulpo_sessions.json | sort -u)

contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "${item}" == "${needle}" ]] && return 0
  done
  return 1
}

while IFS=$'\t' read -r profile room; do
  if ! contains "${room}" "${room_names[@]}"; then
    fail "profiles.json: profile '${profile}' references unknown room '${room}'"
  fi
done < <(jq -r '.[] | .profile as $p | .rooms[] | [$p, .] | @tsv' profiles.json)

while IFS= read -r camera_id; do
  [[ -n "${camera_id}" && "${camera_id}" != "null" ]] || continue
  if ! contains "${camera_id}" "${camera_ids[@]}"; then
    fail "snowls_info.json: camera id '${camera_id}' not found in cameras.json"
  fi
  cal_file="cam_calibrations/calibration_${camera_id}.json"
  if [[ ! -f "${cal_file}" ]]; then
    fail "snowls_info.json: missing ${cal_file} for camera id '${camera_id}'"
  fi
done < <(jq -r '.[].cameras? | .frontId, .rearId' snowls_info.json | sort -u -n)

while IFS= read -r lens; do
  [[ -n "${lens}" ]] || continue
  if ! contains "${lens}" "${lens_names[@]}"; then
    fail "cameras.json: lens '${lens}' not found in lenses.json"
  fi
done < <(jq -r '.[].lens' cameras.json | sort -u)

while IFS= read -r session_id; do
  [[ -n "${session_id}" ]] || continue
  if ! contains "${session_id}" "${pulpo_session_ids[@]}"; then
    fail "rooms.json: conference id '${session_id}' not found in pulpo_sessions.json"
  fi
done < <(jq -r '.[].conference.id' rooms.json | sort -u)

while IFS= read -r dup; do
  [[ -n "${dup}" ]] || continue
  fail "cameras.json: duplicate camera id '${dup}'"
done < <(jq -r '.[].id' cameras.json | sort -n | uniq -d)

while IFS= read -r dup; do
  [[ -n "${dup}" ]] || continue
  fail "rooms.json: duplicate room name '${dup}'"
done < <(jq -r '.[].name' rooms.json | sort | uniq -d)

echo "Validating camera calibrations..."

# OpenCV fisheye model at the calibration image size; K is the lens matrix (Phoenix forwards it
# as fx/fy/cx/cy). Empty {} files are placeholders for cameras not calibrated yet.
# k_convention states what K/D mean. legacy_dualfisheye_unwarp marks hand-tuned values (galileo,
# vaughan) and goes away once they are recalibrated (owl issue #230): drop it from this list.
K_CONVENTIONS='["opencv_fisheye", "legacy_dualfisheye_unwarp"]'
for cal_file in cam_calibrations/calibration_*.json; do
  [[ -f "${cal_file}" ]] || continue
  is_empty_json "${cal_file}" && continue
  problem=$(jq -r --argjson conv "${K_CONVENTIONS}" '
    def mat3: type == "array" and length == 3
      and all(.[]; type == "array" and length == 3 and all(.[]; type == "number"));
    if (.k_convention as $k | any($conv[]; . == $k) | not)
      then "k_convention must be one of \($conv | join(", ")) (got \(.k_convention // "none"))"
    elif (.K | mat3 | not) then "K must be a 3x3 number matrix"
    elif ((.D | type) != "array" or (.D | length) != 4 or ((.D | all(.[]; type == "number")) | not))
      then "D must have 4 numbers"
    elif ((.image_width | type) != "number" or (.image_height | type) != "number"
      or .image_width <= 0 or .image_height <= 0)
      then "image_width and image_height must be positive numbers"
    elif (has("K_orig") and .K != .K_orig)
      then "K differs from K_orig (K must be the lens matrix; re-publish with owl publish-config)"
    else empty end' "${cal_file}")
  if [[ -n "${problem}" ]]; then
    fail "${cal_file}: ${problem}"
    continue
  fi
  convention=$(jq -r '.k_convention' "${cal_file}")
  if [[ "${convention}" != "opencv_fisheye" ]]; then
    warn "${cal_file}: k_convention ${convention} (hand-tuned, not a lens matrix; recalibrate, owl issue #230)"
  fi
  ratio=$(jq -r '.K[0][0] / .image_width * 1000 | round / 1000' "${cal_file}")
  if ! awk -v r="${ratio}" 'BEGIN { exit !(r >= 0.20 && r <= 0.33) }'; then
    warn "${cal_file}: fx / image_width = ${ratio}, outside 0.20-0.33 (fleet fisheye lenses: 0.25-0.27; rectified matrix in K?)"
  fi
done

while IFS=$'\t' read -r name seat; do
  fail "snowls_info.json: ${name} cameras.seat_front_sensor must be 0 or 1 (got ${seat})"
done < <(jq -r '.[] | select((.cameras | type) == "object" and (.cameras | has("seat_front_sensor")))
  | select(.cameras.seat_front_sensor != 0 and .cameras.seat_front_sensor != 1)
  | [.name, (.cameras.seat_front_sensor | tostring)] | @tsv' snowls_info.json)

while IFS=$'\t' read -r name flip; do
  fail "snowls_info.json: ${name} cameras.upright_flip must be 0, 1, 2 or 3 (got ${flip})"
done < <(jq -r '.[] | select((.cameras | type) == "object" and (.cameras | has("upright_flip")))
  | select(.cameras.upright_flip as $f | [0, 1, 2, 3] | any(. == $f) | not)
  | [.name, (.cameras.upright_flip | tostring)] | @tsv' snowls_info.json)

while IFS=$'\t' read -r name camera_id; do
  cal_file="cam_calibrations/calibration_${camera_id}.json"
  if [[ -f "${cal_file}" ]] && is_empty_json "${cal_file}"; then
    warn "snowls_info.json: ${name} uses empty ${cal_file} (not calibrated yet)"
  fi
done < <(jq -r '.[] | select((.cameras | type) == "object") | .name as $n
  | .cameras | (.frontId, .rearId) | select(. != null) | [$n, tostring] | @tsv' snowls_info.json)

echo "Validating stitch files..."

for stitch_file in cam_calibrations/stitch_*.json; do
  [[ -f "${stitch_file}" ]] || continue
  base=$(basename "${stitch_file}" .json)
  if [[ ! "${base}" =~ ^stitch_([0-9]+)-([0-9]+)$ ]]; then
    fail "${stitch_file}: name must be stitch_<frontId>-<rearId>.json"
    continue
  fi
  front_id="${BASH_REMATCH[1]}"
  rear_id="${BASH_REMATCH[2]}"
  for camera_id in "${front_id}" "${rear_id}"; do
    cal_file="cam_calibrations/calibration_${camera_id}.json"
    if [[ ! -f "${cal_file}" ]] || is_empty_json "${cal_file}"; then
      fail "${stitch_file}: references missing or empty ${cal_file}"
    elif [[ "$(jq -r '.k_convention' "${cal_file}")" != "opencv_fisheye" ]]; then
      fail "${stitch_file}: ${cal_file} must have k_convention opencv_fisheye (the stitch needs the lens matrix)"
    fi
  done
  problem=$(jq -r --argjson f "${front_id}" --argjson r "${rear_id}" '
    ["K", "D", "K_orig", "K_rect", "fx", "fy", "cx", "cy", "image_width", "image_height"] as $intr
    | def embeds: type == "object" and any(keys[]; . as $k | $intr | index($k));
    if (.camera_ids != {"front": $f, "rear": $r})
      then "camera_ids must be {\"front\": \($f), \"rear\": \($r)} (file name)"
    elif (.seat_front_sensor != 0 and .seat_front_sensor != 1) then "seat_front_sensor must be 0 or 1"
    elif (embeds or (.lenses.front | embeds) or (.lenses.rear | embeds))
      then "embeds calibration intrinsics; stitch files reference calibration_<id>.json only"
    else empty end' "${stitch_file}")
  if [[ -n "${problem}" ]]; then
    fail "${stitch_file}: ${problem}"
    continue
  fi
  while IFS=$'\t' read -r name seat; do
    fail "${stitch_file}: seat_front_sensor differs from snowls_info.json ${name} (${seat})"
  done < <(jq -r --slurpfile st "${stitch_file}" --argjson f "${front_id}" --argjson r "${rear_id}" '
    .[] | select((.cameras | type) == "object" and .cameras.frontId == $f and .cameras.rearId == $r
      and (.cameras | has("seat_front_sensor"))
      and .cameras.seat_front_sensor != $st[0].seat_front_sensor)
    | [.name, (.cameras.seat_front_sensor | tostring)] | @tsv' snowls_info.json)
done

if [[ "${errors}" -gt 0 ]]; then
  echo "Validation failed with ${errors} error(s)." >&2
  exit 1
fi

if [[ "${warnings}" -gt 0 ]]; then
  echo "Validation passed with ${warnings} warning(s)."
else
  echo "Validation passed."
fi
