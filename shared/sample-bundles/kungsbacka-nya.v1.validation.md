# Kungsbacka Nya V1 Bundle Validation

Generated bundle:

- `shared/sample-bundles/kungsbacka-nya.v1.json`

Generation command:

```powershell
npm --prefix course-studio run publish:pilot
```

Validation command:

```powershell
npm --prefix course-studio run validate:bundle
```

## Foundation Acceptance Checks

- The bundle uses `schema_version: v1`.
- The bundle exposes `course_id`, `course_name`, `bundle_version`, `published_at`, and bundle-level provenance.
- Holes 1-9 are present.
- Each hole has tees, centerline, green reference data, canonical features, strategy overlay containers, quality metadata, and hole-level provenance.
- Known source-data issues are surfaced in `quality_confidence.notes`.
- The iOS-side domain module can decode the canonical shape through `CourseBundleLoader`.

## Ready For Next Slice

This foundation slice is ready to hand off to the first strategy-oriented slice when:

- the generated bundle validates cleanly,
- the iOS loader contract remains aligned with the generated bundle shape,
- and the quality notes are considered acceptable inputs for first-pass overlay derivation.

The next slice should start with overlay derivation and visualization, especially `hazard_severity`, `tee_target_corridor`, and `preferred_miss`.
