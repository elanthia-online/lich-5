# Changing a saved character's frontend

Open **Account Management > Accounts**, expand the account, select a character,
and click **Change Frontend**. Choose a frontend and Save. Cancel leaves the saved
entry unchanged. Use the **Frontends** tab to configure an executable, extra
arguments, or a custom frontend before assigning it to a character.

Changing the association preserves account credentials, favorite status, and any
per-entry custom launch command and directory. It does not log in or change other
characters. Duplicate destination entries and stale selections are rejected;
refresh the account list if another window changed the entry.

An unavailable Wrayth entry is not evidence of bad credentials. Its saved frontend
may simply not be installed on this computer. The launcher error now points to
the configuration controls, and OK dismisses the dialog.

The GTK message-box repair uses the return value of `Gtk::Dialog#run`. Current
Ruby-GNOME GTK3 does not yield to a supplied block, so putting `destroy` inside
that block left the dialog visible even after OK. Response and cleanup regression
tests cover OK, Cancel, Yes, No, and an exception from `run`.
