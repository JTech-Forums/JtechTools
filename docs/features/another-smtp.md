# Another SMTP

Send forum email through a different mail server than the one in `app.yml`. The host, port, TLS, login and optional "From" address rewriting are all set in the admin.

- Mail sent from a group's own inbox (group SMTP) keeps using that group's mail server.
- Leave the address blank to keep using the server's own mail host. The dashboard warns if the relay is switched on without an address.
- Check it with **Send test email** under Admin → Email, which goes through the relay.

## Settings

Admin → Plugins → Jtech Tools → **Another SMTP**. The full text of each setting is shown next to it in the admin.

| Setting | Default | What it does |
| --- | --- | --- |
| `discourse_another_email_enabled` | `false` | Send outbound forum email through the relay configured below instead of the server's DISCOURSE_SMTP_* host. |
| `discourse_another_email_smtp_address` | `(blank)` | Hostname or IP address of the relay — no scheme, port, or path. |
| `discourse_another_email_smtp_port` | `587` | 587 for STARTTLS submission, 465 for implicit TLS, 25 for an unauthenticated relay on a private network. |
| `discourse_another_email_smtp_security` | `starttls_auto` | How the connection to the relay is encrypted. |
| `discourse_another_email_smtp_openssl_verify_mode` | `peer` | Set to "Do not verify" only if the relay presents a self-signed certificate, or one whose name does not match the relay host above. |
| `discourse_another_email_smtp_authentication_mode` | `plain` | SMTP AUTH mechanism used with the credentials below. |
| `discourse_another_email_smtp_username` | `(blank)` | SMTP AUTH user. |
| `discourse_another_email_smtp_password` | `(blank)` | SMTP AUTH password or API key. |
| `discourse_another_email_force_from_domain` | `(blank)` | Replaces the domain of every outgoing From address with this one, keeping the local part (noreply@forum.example becomes noreply@example.com). |
| `discourse_another_email_force_smtp_username_to_sender` | `false` | Logs in to the relay separately for each message, as that message's own From address with any +tag suffix removed, and after the domain rewrite above has been applied. |
| `discourse_another_email_smtp_domain` | `(blank)` | Domain this forum announces in the SMTP HELO/EHLO greeting. |
| `discourse_another_email_smtp_open_timeout_seconds` | `5` | Seconds to wait for the connection to the relay to open before abandoning the delivery. |
| `discourse_another_email_smtp_read_timeout_seconds` | `5` | Seconds to wait for each reply from the relay before abandoning the delivery. |

[← All features](../README.md#features)
