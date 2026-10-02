# Lotoki website transition

Purchased domains verified in Hostinger: lotoki.app, lotoki.com, lotoki.es.
Primary proposed: lotoki.app (communicated assumption; can be changed using the deployment argument).

Current site: trackyourbaby.app on VPS 82.112.254.215.
New domains currently point to Hostinger parking (2.57.91.91).
Nameservers remain managed by Hostinger. No DNS records have been changed yet.

Deploy preserves the old document root and configuration, and backs both up under /var/backups/lotoki/<release-id>. Static website files only are published: no Git data, operations scripts, or restore instructions.

Sequence:
1. Authenticate to existing VPS without changing credentials or SSH access.
2. Run deploy-lotoki.sh with the confirmed primary domain; inspect backups/configuration.
3. Change root A records to the existing VPS, keeping www CNAMEs to their domain.
4. Wait for DNS. Activate with the emitted release ID, issue valid HTTPS for all domains and verify canonical redirects preserving paths.
5. Verify home, Spanish home, privacy and support from outside the server.
6. Keep old app links working during the transition. Configure new mailboxes before changing email addresses.
7. Only then switch app URLs and optionally redirect trackyourbaby.app.

Rollback: restore the previous Lotoki configuration/release from the backup. The original TrackYourBaby configuration is preserved throughout. Do not restore the complete Nginx tree blindly, because the VPS hosts other sites.
