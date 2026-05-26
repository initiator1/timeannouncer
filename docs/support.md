# Support

For TimeAnnouncer support, open an issue at:

https://github.com/initiator1/timeannouncer/issues

If you do not want to post publicly, include only general app behavior in the issue and leave out private machine details.

## Common Checks

If no audio plays:

1. Open the menu bar clock.
2. Choose **Preview Voice**.
3. Confirm the selected voice is ready in the menu.
4. Raise the volume from the **Volume** submenu.
5. If Kokoro is selected, run `./scripts/setup-kokoro.sh` or switch to **System Voice**.

If announcements do not repeat:

1. Confirm the menu says **Announcing**.
2. Check the selected interval.
3. In clock-aligned mode, announcements happen on natural clock boundaries such as `:00`, `:15`, `:30`, or `:45`.

If ElevenLabs does not work:

1. Confirm the API key is saved.
2. Confirm the Mac has internet access.
3. Switch to **System Voice** if cloud speech is unavailable.

## Support Diagnostics

When asking for help, open the TimeAnnouncer menu and choose **Copy Support Diagnostics**. This copies app version, macOS version, announcement settings, voice readiness, Kokoro install status, and whether an ElevenLabs API key is saved.

The diagnostics do not include the ElevenLabs API key itself.
