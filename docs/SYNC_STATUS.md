# Cloud sync check — milestone (not production)

- Supabase project `LaserProStudio` is separate from old manager database.
- Client uses publishable key, Supabase Auth account, and owner-isolated RLS table `lp_sync_records`.
- Local cache now uses a user-scoped filename, preserving legacy local test JSON.
- Edits to initial orders/materials are queued locally and synchronized on save, startup, resume, and periodic refresh.
- Each cloud update performs version-checked compare-and-swap to avoid silently overwriting stale records.
- CONFLICTS ARE NOT AUTOMATICALLY RESOLVED. No production-ready sync yet.
- The definitive product catalog, SVG library, full payments ledger, delivery records, prior purchases screens, and final themes have NOT yet been implemented.
- Do not enter real customer/business data until the final workflow is tested end-to-end.
