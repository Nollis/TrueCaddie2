import { mkdir, readFile, stat, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { validateCourseBundle } from "./validate-bundle.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "..", "..");
const defaultSourceDir = "C:\\Projekt\\TrueCaddie\\Sources\\TrueCaddieAppSupport\\Resources\\Courses";
const defaultOutFile = path.join(repoRoot, "shared", "sample-bundles", "kungsbacka-nya.v1.json");
const derivationVersion = "course-studio-foundation-v2";

const hazardBaseScores = {
  water: 0.9,
  bunker: 0.55,
  woods: 0.7,
  rough: 0.35
};

function argValue(flag, fallback) {
  const index = process.argv.indexOf(flag);
  return index === -1 ? fallback : process.argv[index + 1];
}

async function readJson(filePath) {
  return JSON.parse(await readFile(filePath, "utf8"));
}

function normalizeFeature(feature) {
  const properties = feature.properties ?? {};

  return {
    feature_id: feature.id,
    feature_type: properties.featureType ?? "unknown",
    hazard_kind: properties.hazardKind ?? null,
    geometry: feature.geometry,
    properties: {
      name: properties.name ?? null,
      area_m2: properties.area_m2 ?? null,
      centerline_along_m: properties.centerline_along_m ?? null,
      centerline_distance_m: properties.centerline_distance_m ?? null,
      centerline_side: properties.centerline_side ?? null
    }
  };
}

function normalizeTee(teeSet, sourceHole) {
  const sourceTee = sourceHole.tees?.[teeSet.teeSetId];

  if (!sourceTee) {
    return null;
  }

  return {
    tee_set_id: teeSet.teeSetId,
    name: sourceTee.name ?? teeSet.name,
    tee_coordinate: sourceTee.teeCoordinate,
    tee_length_m: sourceTee.teeLengthMeters,
    is_default: Boolean(teeSet.isDefault)
  };
}

function duplicateFeatureNameNotes(sourceHole) {
  const counts = new Map();

  for (const feature of sourceHole.features ?? []) {
    const name = feature.properties?.name;
    if (!name) {
      continue;
    }

    counts.set(name, (counts.get(name) ?? 0) + 1);
  }

  return [...counts.entries()]
    .filter(([, count]) => count > 1)
    .map(([name, count]) => `duplicate feature name '${name}' appears ${count} times`);
}

function duplicateLandingZoneNotes(sourceHole) {
  const landingZones = (sourceHole.contextPoints ?? []).filter(
    (point) => point.properties?.type === "LandingZone"
  );

  if (landingZones.length <= 1) {
    return [];
  }

  const uniqueKeys = new Set(
    landingZones.map((point) => JSON.stringify({
      id: point.id,
      coordinates: point.geometry?.coordinates
    }))
  );

  if (uniqueKeys.size === landingZones.length) {
    return [];
  }

  return [`${landingZones.length} landing-zone points collapse to ${uniqueKeys.size} unique id/coordinate pair`];
}

function qualityForHole(sourceHole) {
  const notes = [
    ...duplicateFeatureNameNotes(sourceHole),
    ...duplicateLandingZoneNotes(sourceHole)
  ];

  const centerlinePoints = sourceHole.centerline?.coordinates?.length ?? 0;
  const obLines = sourceHole.outOfBoundsLines?.length ?? 0;
  const elevations = [
    sourceHole.greenCenterElevationMeters,
    sourceHole.greenFrontCenterElevationMeters,
    sourceHole.greenBackCenterElevationMeters
  ];

  if (centerlinePoints > 0 && centerlinePoints < 4) {
    notes.push(`centerline has only ${centerlinePoints} points`);
  }

  if (obLines === 0) {
    notes.push("no out-of-bounds lines supplied");
  }

  if (elevations.every((value) => value === undefined || value === null || value === 0)) {
    notes.push("green elevation values are missing or zero");
  }

  const score = Math.max(0.35, Number((1 - notes.length * 0.09).toFixed(2)));
  const confidence = score >= 0.82 ? "high" : score >= 0.6 ? "medium" : "low";
  const hazardCoverage = (sourceHole.features ?? []).filter((feature) =>
    ["water", "bunker", "woods", "rough"].includes(feature.properties?.featureType)
  ).length;

  return {
    hole_publish_confidence: confidence,
    hole_publish_score: score,
    overlay_scores: {
      tee_target_corridor: 0,
      preferred_miss: 0,
      layup_candidates: 0,
      hazard_severity: hazardCoverage > 0 ? Number(Math.min(0.85, 0.45 + hazardCoverage * 0.04).toFixed(2)) : 0
    },
    notes
  };
}

function numericValue(value, fallback = null) {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function severityBand(score) {
  if (score >= 0.85) {
    return "critical";
  }

  if (score >= 0.65) {
    return "high";
  }

  if (score >= 0.4) {
    return "medium";
  }

  return "low";
}

function penaltyKindForFeature(featureType) {
  switch (featureType) {
    case "water":
      return "stroke_penalty";
    case "woods":
      return "recovery_only";
    case "bunker":
      return "recovery_only";
    case "rough":
      return "angle_loss";
    default:
      return "context_only";
  }
}

function hazardReason(featureType, side, along, distance) {
  const sideText = side ?? "unknown side";
  const alongText = along === null ? "unknown distance" : `${along}m along`;
  const distanceText = distance === null ? "unknown separation" : `${distance}m from centerline`;

  switch (featureType) {
    case "water":
      return `water on the ${sideText} at ${alongText} with ${distanceText}`;
    case "woods":
      return `woods on the ${sideText} at ${alongText} can turn a miss into recovery golf`;
    case "bunker":
      return `bunker on the ${sideText} at ${alongText} adds recovery cost`;
    case "rough":
      return `rough on the ${sideText} at ${alongText} reduces control`;
    default:
      return `${featureType} at ${alongText}`;
  }
}

function deriveHazardSeverity(sourceHole, sourceFile) {
  return (sourceHole.features ?? [])
    .filter((feature) => ["water", "bunker", "woods", "rough"].includes(feature.properties?.featureType))
    .map((feature) => {
      const featureType = feature.properties?.featureType;
      const along = numericValue(feature.properties?.centerline_along_m);
      const distance = numericValue(feature.properties?.centerline_distance_m);
      const side = feature.properties?.centerline_side ?? null;
      const relevanceBoost = distance === null ? 0 : Math.max(0, 0.2 - Math.min(distance, 40) / 200);
      const score = Number(Math.min(0.98, (hazardBaseScores[featureType] ?? 0.3) + relevanceBoost).toFixed(2));

      return {
        overlay_id: `hazard-severity-${feature.id}`,
        overlay_type: "hazard_severity",
        course_id: sourceHole.courseId,
        hole_id: String(sourceHole.holeId ?? sourceHole.hole),
        tee_set_id: "all",
        shot_phase: "all",
        geometry: feature.geometry,
        properties: {
          hazard_ref_id: feature.id,
          hazard_kind: feature.properties?.hazardKind ?? featureType,
          severity_band: severityBand(score),
          severity_score: score,
          context_relevance_score: Number(Math.max(0.25, 1 - Math.min(distance ?? 60, 60) / 75).toFixed(2)),
          penalty_kind: penaltyKindForFeature(featureType),
          landing_conflict: distance !== null ? distance <= 20 : false,
          blocks_recovery: featureType === "woods"
        },
        confidence: {
          band: "medium",
          score: 0.72
        },
        rationale: {
          primary_reason: hazardReason(featureType, side, along, distance)
        },
        constraints: {
          derived_from: "course_studio_hazard_v1"
        },
        provenance: {
          source_file: sourceFile,
          derivation_version: derivationVersion
        }
      };
    });
}

function normalizeHole(sourceHole, teeSets, sourceFile, sourceUpdatedAt) {
  const tees = teeSets
    .map((teeSet) => normalizeTee(teeSet, sourceHole))
    .filter(Boolean);
  const hazardSeverity = deriveHazardSeverity(sourceHole, sourceFile);

  return {
    hole_id: String(sourceHole.holeId ?? sourceHole.hole),
    hole_number: sourceHole.hole,
    par: sourceHole.par,
    default_play_direction: sourceHole.defaultPlayDirection ?? null,
    tees,
    base_mapping_data: {
      centerline: sourceHole.centerline,
      green: {
        center: sourceHole.greenCenter,
        front_center: sourceHole.greenFrontCenter,
        back_center: sourceHole.greenBackCenter ?? null,
        center_elevation_m: sourceHole.greenCenterElevationMeters ?? null,
        front_elevation_m: sourceHole.greenFrontCenterElevationMeters ?? null,
        back_elevation_m: sourceHole.greenBackCenterElevationMeters ?? null,
        polygon_feature_id: (sourceHole.features ?? []).find(
          (feature) => feature.properties?.featureType === "green"
        )?.id ?? null
      },
      features: (sourceHole.features ?? []).map(normalizeFeature),
      out_of_bounds_lines: sourceHole.outOfBoundsLines ?? [],
      context_points: sourceHole.contextPoints ?? []
    },
    strategy_overlays: {
      tee_target_corridors: [],
      aggressive_tee_corridors: [],
      layup_candidates: [],
      preferred_miss: [],
      hazard_severity: hazardSeverity
    },
    quality_confidence: qualityForHole(sourceHole),
    provenance: {
      source_system: sourceHole.source ?? "manual-editor",
      source_file: sourceFile,
      source_updated_at: sourceHole.updatedAt ?? sourceUpdatedAt,
      derivation_version: derivationVersion
    }
  };
}

async function buildBundle(sourceDir) {
  const manifestFile = path.join(sourceDir, "kungsbacka-nya-manifest.json");
  const manifest = await readJson(manifestFile);
  const manifestStat = await stat(manifestFile);
  const holes = [];

  for (const holeRef of manifest.holes) {
    const sourceFile = `${holeRef.file}.json`;
    const sourcePath = path.join(sourceDir, sourceFile);
    const sourceHole = await readJson(sourcePath);
    const sourceStat = await stat(sourcePath);

    holes.push(normalizeHole(
      sourceHole,
      manifest.teeSets ?? [],
      sourceFile,
      sourceStat.mtime.toISOString()
    ));
  }

  return {
    schema_version: "v1",
    bundle_version: "kungsbacka-nya.v1.foundation",
    course_id: manifest.courseId,
    course_name: manifest.name,
    published_at: new Date().toISOString(),
    provenance: {
      source_system: "truecaddie-pilot-json",
      source_path: sourceDir,
      source_file: "kungsbacka-nya-manifest.json",
      source_updated_at: manifestStat.mtime.toISOString(),
      derivation_version: derivationVersion
    },
    holes
  };
}

async function main() {
  const sourceDir = path.resolve(argValue("--source", defaultSourceDir));
  const outFile = path.resolve(argValue("--out", defaultOutFile));
  const bundle = await buildBundle(sourceDir);
  const validation = validateCourseBundle(bundle);

  if (!validation.valid) {
    for (const error of validation.errors) {
      console.error(`- ${error}`);
    }
    process.exitCode = 1;
    return;
  }

  await mkdir(path.dirname(outFile), { recursive: true });
  await writeFile(outFile, `${JSON.stringify(bundle, null, 2)}\n`, "utf8");

  console.log(`Published ${bundle.course_id} ${bundle.bundle_version}`);
  console.log(`Holes: ${bundle.holes.length}`);
  console.log(`Output: ${outFile}`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
