Required steps to setup the web application
-------------------------------------------

Dependencies: node, npm, postgres, linux, git


1.  Ensure node is installed. Locally is preferable, to ensure proper verisons. 


        sh install_node.sh


2. Ensure postgres is installed. This is a bit more involved and hasn't been scripted. This README will loosely guide the steps.

    On your linux box, run the equivalent packagement tools to install at least the latest version of git and recently modern version of postgres, say 9.X for these scripts.

        sudo apt-get install g++
        sudo apt-get install git
        sudo apt-get install postgresql-9.2 postgresql-server-dev-9.2 postgresql-contrib-9.2
    
    With those two last commands, I installed postgres v9.2, but v9.1 may work as well. The server development files are needed by the node postgres bindings.  For the necessary changes made post-install, following the instructions here:
    https://help.ubuntu.com/10.04/serverguide/postgresql.html
    Note: I have documented my steps as best as possible here, but you should read the PostgreSQL admin guide if you want more in-depth information that is out of scope for this README. This is by no means a complete setup to secure everything.

3. Modify postgresq.conf:


        sudo vim /etc/postgresql/9.2/main/postgresql.conf

    On my version, I changed line 59 to remove the hashtag/pound sign.

        listen_addresses = 'localhost'

        Note: this should be an external IP address to allow external connections 
    
    If the kernel of the machine is configured with a high SHMMAX, I might bump up the shared memory setting:
    
        
        shared_buffers = 64MB
        
4. Changed the default postgres user password according to the instructions given in the link above.
5. Modify pg_hba.conf:


        sudo vim /etc/postgresql/9.1/main/pg_hba.conf 

    changed the first two non-commented lines to use 'md5' hashing:

        local   all             postgres                                md5
        local   all             all                                     md5

6. Execute install_pg_roles.sh to install the roles and the main database: platform. The password set in Step 4 is required for this step.


        sh install_pg_roles.sh <name_of_super_user> <name_of_regular_user>
        
    Note: the name of these roles must then be configured in the installation of the secret.js file in Step 9.

7. Git clone this repository to the desired location on the server. Change directories to that folder and run: 


        npm install
    
8. If you want, you can install the coffee script parser 'globally'.


        npm install -g coffee-script@1.6.3


9. Create the secrets.js password file in the config folder (chmod 400), necessary to install the schemas.
 
        module.exports = {
            PG: {
                app: {
                    user: 'application_user',
                    password: 'normal_secretz'
                },
                superuser: {
                    user: 'privileged_user',
                    password: 'top_secretz'
                }
            }
        } 


10. Install the schema and table definitions necessary by running the following commands:


        export NODE_ENV=superuser 
        coffee resources/pg_install.coffee --extension
        coffee resources/pg_install.coffee --schema
        coffee resources/pg_install.coffee --table
        coffee resources/pg_install.coffee --function platform

    Sometimes, creating the extensions does work as scripted, hence the multiple steps. If installing the extensions does not work because of an older version of postgresql, then refer to this link on how to install the contrib modules:
    http://www.postgresql.org/docs/8.3/static/contrib.html
    
11. Optional - Run the tests to make sure everything is working as expected.

        
        export NODE_ENV=test
        # the installation only has to be run once
        coffee resources/pg_install.coffee --extension
        coffee resources/pg_install.coffee --schema
        coffee resources/pg_install.coffee --table
        coffee resources/pg_install.coffee --function platformtest
        npm test
        
12. Install the forever service to keep the app running:
    
    
        npm install -g forever

13. Configure any firewall or proxy needs, including setting: 
     1. the NODE_ENV variable, i.e. set it to 'production'
     2. the 'production' configuration files under config/* 
        * This file must be copied and modified from the default.coffee file on first install.
        * The host/port address
        * Create the configured 'uploads' directory in the top level directory
        * A location to store the logs from the app, a.k.a. forever logs

14. Start the app:

        forever -c coffee start app.coffee

