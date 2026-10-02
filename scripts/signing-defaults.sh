# Shared release signing defaults.
# Source from build-release.sh and smoke-release.sh so the smoke check cannot
# demand a different name than the build uses.
#
# Sign as INITIATOR LLC, not the personal Developer ID (2026-07-26). Gatekeeper
# shows this string. 1.0.0 shipped the personal name. The Apple account is now
# an organization; Apple does not rename certificates, so a new Developer ID
# was issued under the org. This default must point at it or every build and
# smoke silently reverts to the old identity.
TEAM_ID="${TEAM_ID:-MDWFZC6396}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: INITIATOR LLC (${TEAM_ID})}"
