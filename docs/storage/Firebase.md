# Firebase for vimflowy

## Info

Firebase is a cloud service ran by Google.
Thus if you set up Vimflowy to use Firebase, your data will sit on Google's servers.

Note: As with all remote data implementations, you will be unable to access Vimflowy offline.
However, you will be able to access it from multiple devices.

## Setup

### Obtain a Firebase project

To use the Firebase backend, you should first set up a Firebase instance.
You can do this by clicking `CREATE NEW PROJECT` at https://console.firebase.google.com/.
You should use the older "Realtime Datbase", *not* firestore.

You should then be given your own Firebase project id (or "Realtime Database URL"),
something like `something-fiery-2222`.
You should be able to now visit your console at a link like
https://console.firebase.google.com/project/${projectId}, e.g.
https://console.firebase.google.com/project/something-fiery-2222.

### Set up authentication

#### Add a user

Visit the Authentication tab.

- Under `Authentication > Sign-In Method` (https://console.firebase.google.com/project/${projectId}/authentication/providers), enable email/password.

- Under `Authentication > Users` (https://console.firebase.google.com/project/${projectId}/authentication/users), click `Add User`.
  Pick an email and password, and enter it.
  Remember the email/password pair - you'll need them later!

#### Set up database rules

Visit the `Database > Rules` section (https://console.firebase.google.com/project/${projectId}/database/rules).
The rules should look like this:

```
{
    "rules": {
        ".read": "auth != null",
        ".write": "auth != null"
    }
}
```

This default should work fine, but will give you email warnings about security. You can silence these emails in settings, or add an extra layer of security:

```
{
    "rules": {
        ".read": "auth != null && auth.uid == '<UID in Auth Page>'",
        ".write": "auth != null && auth.uid == '<UID in Auth Page>'"
    }
}
```

See [here](https://github.com/WuTheFWasThat/vimflowy/issues/370) for details

### Configure Vimflowy

Now, in the general settings menu (https://console.firebase.google.com/project/${projectId}/settings/general/)
find your API key.
Together with the project ID, and user information from earlier,
we have everything needed to configure Vimflowy to use Firebase.

Simply go to your tab with Vimflowy, and click Settings in the lower right.
Select the Firebase option under `Data Storage`.
Then enter in the four fields into the corresponding input boxes,
and hit `Load Data Settings`.
This should refresh the page automatically.
Assuming configuration was correct and no errors occurred,
you should now be using Firebase!

### Verify

To verify Vimflowy is properly working with Firebase, check the settings menu again and you should see that the Firebase is already selected.

You may also want to verify that the security rules are working.
To do this, try changing the email/password pair to something invalid.
After the page refresh, you should immediately see an error alert.

## Backups

You can pay Firebase for automated backups of your data.
See https://console.firebase.google.com/project/${projectId}/database/backups
