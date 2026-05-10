# gNMI / model-driven telemetry (Phase B — deferred)

Do **not** enable **gNMI**, **GRPC dial-out**, or similar on the lab CSRs while they run **IOS-XE 16.05.x**.

**Gate (from design):** upgrade at least one CSR to **IOS-XE ≥ ~16.11 / 17.x**, then re-open **[`../../design/2026-05-10-tigger-TIG-snmp-phased.md`](../../design/2026-05-10-tigger-TIG-snmp-phased.md)** Phase B and choose **Telegraf `inputs.gnmi`** vs router **dial-out**.

Until then, **SNMP** (**Phase A2**) is the supported metrics path on **TIGger**.
