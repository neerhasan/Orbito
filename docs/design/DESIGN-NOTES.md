# Design notes (Ember UI)

- Look: a dark shell with paper-coloured panels. One accent colour, orange #FF5A1F, which means "now" (the current item, the active timer). Do not use it for decoration.
- Font: Inter.
- Project colours (not orange): blue, green, violet, amber, pink, teal, brown, slate.
- `source/` holds the design screens as HTML files (they were made for a design tool and may not open correctly on their own). Read them for layout, spacing and wording. `source/ember.css` holds the colours and component styles. `source/canvas.json` lists which screen is which.
- `screens-reference/` holds pictures of the working prototype, one per section. They show empty data, so they show layout only.
- The screens still show the old name "Life System". The app is Orbito.
- Desktop screens are 1440 pixels wide. For Android, only two Today layouts exist (`MobileTodayA`, recommended, and `MobileTodayB`). Use A. Other Android screens are not designed yet: adapt the desktop screens to a phone using the same styles, and ask the founder when unsure.
- Not yet designed: energy modes and the mode switcher, the fail-day next step, sync status and "paused" states, the account page (devices, export, delete), password reset and email verification. Design these simply in the same style and ask the founder to review.
- The design was not formally approved. The founder will give a change list after testing.
