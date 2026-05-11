# TrueCaddie Course Studio

Course Studio prepares course data before it reaches the iOS app.

The first implementation slice publishes the `kungsbacka-nya` pilot data into the shared V1 course bundle format.

The publisher and validator both use the shared JSON Schema in:

`shared/course-bundle-schema/course-bundle.v1.schema.json`

## Publish The Pilot Bundle

```powershell
node course-studio/app/publish-kungsbacka-nya.mjs
```

By default, the publisher reads from:

`shared/pilot-data/kungsbacka-nya`

Use `--source <path>` to read from another directory and `--out <file>` to write somewhere else.
