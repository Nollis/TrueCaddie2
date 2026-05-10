# Course Bundle Schema

This directory owns the shared data contract between TrueCaddie Course Studio and TrueCaddie Mobile.

The V1 bundle is split into:

- bundle identity and provenance
- per-hole base mapping data
- strategy overlay containers
- quality and confidence metadata

The schema is intentionally small for the first foundation slice. Later changes can add stricter geometry validation and richer strategy overlays without moving the contract out of `shared/`.
