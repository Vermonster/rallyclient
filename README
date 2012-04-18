Rally CLI (.v1)
=====

rally --help

rally.rc (config)
- url (e.g. http://rallyclock.com)
- api_key

API endpoints
rally ping
GET /system/ping

rally sign_up --username 'blah' --email 'blah@blah'
register (save credentials to rally.rc)
POST /users
  - username
  - email

rally whoami
whoami?
GET /me

rally projects
what projects am i assigned to?
GET /me/projects


rally entries --from 'blah', --to 'blah'
get my entries
GET /me/entries
  - from ('YYYY-MM-DD')
  - to ('YYYY-MM-DD')

rally entry --id 'blah'
get a single entry
GET /me/entries/:id
  - id 

rally commit --handle 'blah' --code 'blah' --time 'blah', --note 'blah' --date 'blah'
create an entry
POST /:handle/projects/:code/entries
  - handle
  - code
  - time ('6h20m')
  - note
  - date

rally edit --handle 'blah' --id 'blah' --note 'blah' --time 'blah' --date 'blah'
edit an entry
PUT /:handle/projects/:code/entries/:id




