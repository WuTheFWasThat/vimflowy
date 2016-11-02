## Setup

### Obtain a Firebase project

To use the Firebase backend, you should first set up a Firebase instance.
You can do this for free at https://firebase.google.com/.

You should then be given your own Firebase project id,
something like `something-fiery-2222`.
You should be able to now visit your console at a link like
https://console.firebase.google.com/project/${projectId}, e.g.
https://console.firebase.google.com/project/something-fiery-2222.
For the remainder of this document, we will refer to that link as `${BASE_URL}`;

### Add a user

Visit the Authentication tab.

- Under `Authentication > Sign-In Method` (${BASE_URL}/authentication/providers), enable email/password.

- Under `Authentication > Users` (${BASE_URL}/authentication/users), click `Add User`;
  Pick an email and password, and enter it.
  Remember the email/password pair - you'll need it later!

### Set up database rules

In the database rules section, set up rules like this:

```
{
    "rules": {
        ".read": "auth != null",
        ".write": "auth != null"
    }
}
```

### Configure Vimflowy

Now, in the general settings menu (${BASE_URL}/settings/general/)
find your API key.
Together with the project ID, and user information from earlier,
we have everything needed to configure Vimflowy to use Firebase.

Simply go to your tab with Vimflowy, and click Settings in the lower right.
Select the Firebase option under `Data Storage`.
Then enter in the four fields into the corresponding input boxes,
and hit `Load Data Settings`.
This should refresh the page automatically.
Assuming configuration was correct and no errors occurred,
you should now be using Firebase.

To verify, check the settings menu again and you should see that the Firebase
is already selected, and the settings already filled.

#### Manual configuration (optional)

NOTE: you can also manually configure in the Javascript console with the following code:
```
var firebaseId = 'something-fiery-2222'
var firebaseApiKey = 'some-key'
var firebaseUserEmail = 'your-email-from-earlier'
var firebaseUserPassword = 'your-password-from-earlier'

window.session.settings.setSetting('dataSource', 'firebase')
window.session.settings.setSetting('firebaseId', firebaseId)
window.session.settings.setSetting('firebaseApiKey', firebaseApiKey)
window.session.settings.setSetting('firebaseUserEmail', firebaseUserEmail)
window.session.settings.setSetting('firebaseUserPassword', firebaseUserPassword)
```

and then manually refresh the page!

## Backups

You can pay Firebase for automated backups of your data.
See ${BASE_URL}/database/backups
