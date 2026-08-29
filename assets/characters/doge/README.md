# Doge presentation assets

The 30 transparent WebP poses are migrated from the repository's read-only
legacy `Dorian/public/assets/poses/doge/` art set. A5 rebinds those authored
images to v2 presentation keys; gameplay boxes, timing, and simulation state do
not depend on image dimensions.

Both the base and Super Doge manifests store a `FEET_CENTER` pivot for every
animation frame. Runtime visuals use the shared `ProductionFighterVisual`
adapter with a top-left sprite anchor; do not restore the former centered-sprite
exception. When replacing a pose, regenerate or update its manifest pivot from
the authored fighter origin. For this temporary 360×360 legacy set, X remains
the canvas center and Y is the lowest opaque body baseline; this prevents pose
changes from introducing horizontal jitter while keeping the art aligned with
the fighter origin independently of gameplay boxes.
