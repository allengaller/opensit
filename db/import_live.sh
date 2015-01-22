rake db:drop
rake db:create
rake db:migrate
heroku pgbackups:capture --expire -a opensit
curl -o latest.dump `heroku pgbackups:url -a opensit`
pg_restore --verbose --data-only --no-acl --no-owner -h localhost -U dan -d opensit_development latest.dump
rm latest.dump
