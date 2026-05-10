import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";

const requiredOverlayKeys = [
  "tee_target_corridors",
  "aggressive_tee_corridors",
  "layup_candidates",
  "preferred_miss",
  "hazard_severity"
];

function hasPosition(value) {
  return Array.isArray(value)
    && value.length === 2
    && value.every((coordinate) => typeof coordinate === "number");
}

function pushIf(errors, condition, message) {
  if (condition) {
    errors.push(message);
  }
}

export function validateCourseBundle(bundle) {
  const errors = [];

  pushIf(errors, bundle?.schema_version !== "v1", "schema_version must be v1");
  pushIf(errors, !bundle?.bundle_version, "bundle_version is required");
  pushIf(errors, !bundle?.course_id, "course_id is required");
  pushIf(errors, !bundle?.course_name, "course_name is required");
  pushIf(errors, !Array.isArray(bundle?.holes), "holes must be an array");

  for (const hole of bundle?.holes ?? []) {
    const label = `hole ${hole?.hole_id ?? "unknown"}`;

    pushIf(errors, !hole.hole_id, `${label}: hole_id is required`);
    pushIf(errors, typeof hole.hole_number !== "number", `${label}: hole_number must be numeric`);
    pushIf(errors, typeof hole.par !== "number", `${label}: par must be numeric`);
    pushIf(errors, !Array.isArray(hole.tees) || hole.tees.length === 0, `${label}: tees are required`);
    pushIf(errors, !hole.base_mapping_data?.centerline?.coordinates, `${label}: centerline is required`);
    pushIf(errors, !hasPosition(hole.base_mapping_data?.green?.center), `${label}: green center is required`);
    pushIf(errors, !Array.isArray(hole.base_mapping_data?.features), `${label}: features must be an array`);

    for (const tee of hole.tees ?? []) {
      pushIf(errors, !tee.tee_set_id, `${label}: tee_set_id is required`);
      pushIf(errors, !hasPosition(tee.tee_coordinate), `${label}: tee ${tee.tee_set_id} has invalid coordinate`);
      pushIf(errors, typeof tee.tee_length_m !== "number", `${label}: tee ${tee.tee_set_id} has invalid length`);
    }

    for (const key of requiredOverlayKeys) {
      pushIf(
        errors,
        !Array.isArray(hole.strategy_overlays?.[key]),
        `${label}: strategy_overlays.${key} must be an array`
      );
    }

    pushIf(errors, !hole.quality_confidence?.hole_publish_confidence, `${label}: confidence band is required`);
    pushIf(errors, typeof hole.quality_confidence?.hole_publish_score !== "number", `${label}: confidence score is required`);
    pushIf(errors, !Array.isArray(hole.quality_confidence?.notes), `${label}: quality notes must be an array`);
    pushIf(errors, !hole.provenance?.source_file, `${label}: provenance.source_file is required`);
  }

  return {
    valid: errors.length === 0,
    errors
  };
}

async function main() {
  const filePath = process.argv[2];

  if (!filePath) {
    console.error("Usage: node course-studio/app/validate-bundle.mjs <bundle.json>");
    process.exitCode = 1;
    return;
  }

  const bundle = JSON.parse(await readFile(filePath, "utf8"));
  const validation = validateCourseBundle(bundle);

  if (!validation.valid) {
    for (const error of validation.errors) {
      console.error(`- ${error}`);
    }
    process.exitCode = 1;
    return;
  }

  console.log(`Bundle is valid: ${bundle.course_id} ${bundle.bundle_version}`);
  console.log(`Holes: ${bundle.holes.length}`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
