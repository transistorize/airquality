# Get Started

To get started, define a secrets.js file with the following structure:

    module.exports = {
        PG: {
            app: {
                user: 'application',
                password: 'application_password'
            },
            superuser: {
                user: 'internal',
                password: 'internal_password'
            }
        }
    }

Be sure to change the user names and passwords appropriately.
