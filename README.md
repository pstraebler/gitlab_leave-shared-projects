# gitlab_leave-shared-projects

Use the Gitlab API to massively leave projects that has been shared with you.

By default, the script only lists repositories for a given year and generate a file named `'projects-$year.csv`.    

You must then **create** a new file named `projects-to-leave-$year.csv` and add the` --leave` option to be removed from the projects presents in the new csv file.  

Filtering is based on project creation date (not modification date).  

You need to install `curl` and `jq` with your favorite package manager.

## Environment variables

You must fill 3 variables in the .env file :

### Gitlab Server

`GITLAB_SERVER`

The Gitlab server you want to interact with.

### Access Token

`PRIVATE_TOKEN`

You need to generate a personnal access token :
In Gitlab, go to 'Preferences' and then 'Access Token'.  
Check 'api, read_api, read_repository, write_repository'

### User ID

`USER_ID`

You also need to get your user id :
In Gitlab, go to 'Preferences' and then 'Profile'.
Or, use the API:
`curl --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" https://$GIT_SERVER/api/v4/user" | jq`



## Usage :

    ./leave-shared-projects.sh [--leave] YEAR-TO-DELETE
