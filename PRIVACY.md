# Deflow Privacy Policy

Last updated: November 16, 2026

Deflow is a macOS app that reminds you of meetings by reading your Google Calendar. This policy
describes what it accesses and what happens to that data.

## What Deflow accesses

When you sign in with Google, Deflow requests one permission: read-only access to Google Calendar
(`https://www.googleapis.com/auth/calendar.readonly`). It uses that to read:

1. The list of calendars you own.
2. Events on those calendars from 15 minutes ago to 24 hours ahead: title, start and end time,
   location, description, attendee names or email addresses, and video-call details.

Deflow cannot create, change or delete anything in your Google account.

## How the data is used

Calendar data is used only on your Mac, only to show your upcoming meetings in the menu bar and to
display the full-screen reminder when a meeting starts.

## Where the data goes

1. **Nowhere but your Mac.** Deflow connects directly from your computer to Google's servers. There is
   no Deflow server, and the developer never receives your calendar data or your Google credentials.
2. **No analytics, tracking or advertising.** Deflow collects no usage data.
3. **No sharing or selling.** Your data is not transferred to anyone, and it is not used to train AI or
   machine-learning models.

## What is stored

1. Calendar events are held in memory while the app runs and are not written to disk.
2. A Google refresh token is stored in your macOS Keychain so you stay signed in.
3. Your settings (lead time, chime, filters) are stored in macOS preferences on your Mac.

## Removing access and data

1. Choose **Disconnect** in the Deflow menu to delete the stored token.
2. Revoke Deflow's access at any time at <https://myaccount.google.com/permissions>.
3. Deleting the app removes everything else.

## Google API Services disclosure

Deflow's use and transfer of information received from Google APIs adheres to the
[Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy),
including the Limited Use requirements.

## Contact

Questions or requests: open an issue on this GitHub repository.
