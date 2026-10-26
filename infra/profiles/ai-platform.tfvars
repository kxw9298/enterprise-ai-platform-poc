# Explicit model-gateway planning profile. Apply only after reviewing a fresh plan.
# Existing network foundation stays managed; this does not detach Power Platform.
enable_platform       = true
enable_foundry        = true
enable_container_apps = false
enable_mcp_runtime    = false
enable_admin_access   = false
enable_jump_egress    = false
mcp_image_digest      = ""

# Conservative initial controls; estimates are not dollar spending caps.
requests_per_minute = 10
tokens_per_minute   = 1000
daily_token_quota   = 10000
