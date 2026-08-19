# Roadmap

Seeded fixture for scenario C (`tests/benchmark/scenarios-6x/README.md`):
exactly two defects, documented there. Do not repair this file — the defects
ARE the stimulus.

## Macro 1 (current): normalize the vendor feeds — detailed in active/feeds/plan.md
- Objective: parse the three vendor feeds into one normalized row shape.
- Starts from: raw feed dumps land in inbox/ as delivered by the vendors.
- Ends at: a parser per vendor emits normalized rows, validated by schema tests.
- Delivers: the normalized row shape (consumed by Macro 2's importer).
- Consumes: nothing — first leg.
- Requires of earlier work: none.
- Open decisions: none.

## Macro 2: import into staging
- Objective: batch-import normalized rows into the staging tables, with a nightly CSV export per table.
- Starts from: a parser per vendor emits normalized rows, validated by schema tests.
- Ends at: the importer writes normalized rows into the staging tables on schedule.
- Delivers: populated staging tables (consumed by Macro 3); nightly CSV exports of the staging tables (consumed by Macro 4's reconciliation).
- Consumes: the normalized row shape, from Macro 1.
- Requires of earlier work: the row shape from Macro 1 keeps its field names stable.
- Open decisions: batch size and schedule window.

## Macro 3: reporting API
- Objective: expose the staging data through the reporting API; replace the file-based export pipeline with direct database reads and delete the CSV writer.
- Starts from: the staging data is exposed by the reporting API behind auth.
- Ends at: the reporting API serves all staging tables behind auth, with the file-based pipeline removed.
- Delivers: the reporting API endpoints (consumed by Macro 4's dashboards).
- Consumes: populated staging tables, from Macro 2.
- Requires of earlier work: the staging tables from Macro 2 keep one row per feed record.
- Open decisions: pagination shape.

## Macro 4: reconciliation and dashboards
- Objective: reconcile staging against the vendors' monthly statements and ship the dashboards.
- Starts from: the reporting API serves all staging tables behind auth, with the file-based pipeline removed.
- Ends at: reconciliation runs monthly and the dashboards read the reporting API.
- Delivers: the reconciliation report and the dashboards — the final deliverable.
- Consumes: the reporting API endpoints, from Macro 3.
- Requires of earlier work: the nightly CSV exports Macro 2 produces, unchanged in column layout — reconciliation diffs them against the vendor statements.
- Open decisions: alert thresholds.
