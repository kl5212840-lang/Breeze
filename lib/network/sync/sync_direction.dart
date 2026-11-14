/// Record conflicts retain their normal merge rules in every mode. Only
/// settings, accounts and artwork follow the explicitly selected direction.
enum SyncDirection { merge, upload, restore, recordsOnly }
