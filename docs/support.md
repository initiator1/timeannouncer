# Support

Email **support@initiatorworks.com** or
[open an issue](https://github.com/initiator1/timeannouncer/issues).
Email does not require a GitHub account. GitHub issues are public, so review
machine details before posting them.

## Start with System Voice

1. Open the menu bar clock, or reopen Time Announcer from Applications.
2. Choose **Voice > System Voice (macOS)**.
3. Choose **Preview Voice**.
4. Raise the app's **Volume** if needed.
5. Check your Mac's output volume and selected output device.

A fresh install starts paused at 25% app volume. Updates keep your prior volume.
Choose **Resume Announcements** after the preview sounds right.

## Announcements do not repeat

Check that the menu says **Announcing**. Check the interval and timing mode.
Clock-aligned mode waits for the next matching clock boundary. For example, a
15-minute interval speaks at `:00`, `:15`, `:30`, and `:45`.
Fixed Interval accepts any positive whole number of minutes and speaks immediately
when resumed. Announcements require the app to run and the Mac to remain awake.
Use **Announce Time Now** to check speech without waiting for a boundary.

## An optional voice is unavailable

The voice status can show preparation, playback, or fallback to System Voice.
A saved API key or installed Python executable does not prove that voice can speak.
Use **Preview Voice** to check it.

For Kokoro, choose **Voice > Install Kokoro...** or **Repair Kokoro Install...**.
Copy the command and read its setup requirements before running it in Terminal.
Setup downloads dependencies and model files. Complete it while online, then
select Kokoro and preview it again. If setup fails, keep using System Voice.
Include the last error message when asking for help. Do not delete the working
Kokoro environment before a repair is understood.

For ElevenLabs, check your connection and the API key saved through
**Voice > Set ElevenLabs API Key...**. Requests may use your account's paid credits.
Choose **System Voice (macOS)** to stop new cloud speech requests.
Never include the API key in a support message.

## Launch at login needs approval

Choose **Launch at Login: Approval Needed…** to open the macOS login settings.
Allow Time Announcer there if you want it to start after login.
The menu reads the system's current registration status. An enabled setting alone
does not verify a future login, so confirm the app returns after your next login.

## Update or recover

**Check for Updates…** shows the installed version and offers **Open Releases**.
This opens a web page. It does not install an update.

Quit Time Announcer before replacing it in Applications. Launch the replacement
and use **Copy Support Diagnostics** to confirm its version. Opening a replacement
bundle while an older copy still runs can leave the old process active.

If an update fails, quit it and restore the previous app bundle from a saved copy
or a prior GitHub release. Keep preferences, Keychain items, and Kokoro folders.
Replacing the app does not require deleting those data. Maintainer recovery steps
are in [publishing](publishing.md).

## Send useful diagnostics

Choose **Copy Support Diagnostics**. It copies the app version, macOS version,
announcement settings, voice setup indicators, and whether an API key is saved.
It does not include the API key. These setup indicators do not prove successful
playback or launch after login.

Review the copied text. Send it with the action you took and the result you heard
or saw. Include whether the issue happens with System Voice. Do not send secrets.
