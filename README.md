# openmusca.github.io

Source of the OpenMusca project website (https://openmusca.github.io), built with MkDocs and the Material theme.

The pages under `docs/` (except `index.md`) are generated from the project documentation by a script in the main
project (`tools/site/build.sh`) and copied here. Edit the documentation there, not here; changes made directly in
this repository are overwritten by the next sync.

Local build (needs Docker, or Python 3.12 with `--inner`):

    sh scripts/mkdocs-build.sh        # pinned requirements with hashes, `mkdocs build --strict` into ./site

The site loads no external fonts, scripts, trackers or analytics.

Unofficial community project, not affiliated with or endorsed by PETKIT. Licence: MIT, see `LICENSE`.
