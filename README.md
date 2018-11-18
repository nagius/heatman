Heatman
=======

Heatman is a web application used to manage power consumption of electrical heaters.

It provide a scheduler to automatically switch ON and OFF your heater, or boiler or anything else. It also allow you to override the current scheduled mode using the web interface. So you can control your heaters with your smartphone while you're away.

Plugins scripts
---------------

All actions on the electrical system will be done by calling scripts. Up to you to use what you want in these scripts (GPIO, USB, X10 adaptor...).

This script should take one of the defined mode as an argument to change the status of the electric device, and also the "status" argument to display the current mode. Example :


```
$ /usr/local/sbin/boiler.sh on
  # Boiler switched to on
$ /usr/local/sbin/boiler.sh status
on
```

### Configuration example

```
timer: "5m"

channels:
  lights:
    label: "My fancy lights"
    command: "sudo /usr/local/sbin/lights"
    modes:
      - "blue"
      - "yellow"
      - "green"
      - "off"
    schedules:
      blue: "17:00-19:00"
      yellow: "Monday 09:00-09:30, Sunday 12:00-13:00"
    default: "off"
```

In this example, the light will be switched to "blue" each day between 5pm and 7pm, and switched to "yellow" on Monday at 9am for half an hour, and on Sunday at noon for one hour. It will be "off" the rest of the time.

See https://github.com/jrobertson/chronic_between for more example of scheduler syntax.

All overrides and scheduled settings specified at runtime via the API will be saved and re-applied on restart. The directory configured by `datadir:` need to be writable.

Installation
------------

```
apt-get install ruby ruby-dev g++

cd /srv/www/
git clone https://github.com/nagius/heatman.git
cd heatman/
gem install bundler
bundle install

cp misc/boiler.sh misc/heaters.sh /usr/local/sbin/

cp config/config.yml.example config/config.yml
```

Take a look at the scripts boiler.sh and heaters.sh, these are examples. Edit them to fit your electric setup.


Development run
---------------

```
rerun "rackup -p 9393"
```

And point your browser to http://localhost:9393

Production run
--------------

As this is a small setup with few requests and designed to run on a Raspberri Pi, a full heavy-production stack like Apache/Passenger or Nginx/Unicorn is not the best option, even if it will work. Instead, the simple setup described here, using Thin as application server and Nginx as front-facing server seems to be more appropriate.

The use of RVM or Rbenv is recommended.

### Thin configuration

```
thin install
cp misc/heatman.yml /etc/thin/
mkdir /var/log/thin
mkdir /var/run/thin
chown www-data.www-data /var/run/thin/
```

### Nginx configuration with SSL and password

```
apt-get install nginx
```

* Password configuration

```
apt-get install apache2-utils
htpasswd -c /etc/nginx/.htpasswd heatman
```

* SSL configuration

```
mkdir /etc/nginx/ssl
openssl genrsa -out /etc/nginx/ssl/privkey.pem 2048
openssl req -new -x509 -key /etc/nginx/ssl/privkey.pem -out /etc/nginx/ssl/cacert.pem -days 1095
```

* Sudo configuration

In /etc/sudoers :

```
www-data ALL=NOPASSWD: /usr/local/sbin/boiler.sh, /usr/local/sbin/heaters.sh
```

* Nginx configuration

In /etc/nginx/conf.d/heatman.conf :

```
server {

        listen 443;
        server_name mydomain.tld;

        access_log /var/log/nginx/access.log;
        error_log /var/log/nginx/error.log;

        ssl on;
        ssl_certificate /etc/nginx/ssl/cacert.pem;
        ssl_certificate_key /etc/nginx/ssl/privkey.pem;

        location / {
                auth_basic "Restricted";
                auth_basic_user_file /etc/nginx/.htpasswd;

                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_redirect off;
                proxy_pass http://unix:/var/run/thin/heatman.0.sock:/;
        }
}
```

* Start

```
/etc/init.d/thin start
/etc/init.d/nginx start
```

And point your browser to https://mydomain.tld/


REST API
--------

All actions could be done via this API, which is used by the JQuery web page.

* GET /api/channels

Return the hash table of available channels with corresponding mode and label.

* GET /api/channel/\<channel_name\>

Return the current mode of the specified channel.

* POST /api/channel/\<channel_name\>/\<mode\>

Override the current channel's mode. 

Mode can be 'auto' to switch back to scheduled mode.
If the parameter ''persistent=true'' is send, the scheduler will be permanently disabled for this channel.
Return ''200 OK'' is the state has been changed, or ''204 No content'' if the requested mode was already enabled.

* GET /api/schedules

Return the current hash of scheduled overrides.

* POST /api/channel/\<channel\>/schedule/\<mode\>
Params : timestamp=\<unixtimestamp\>

Schedule a new override.
Mode can be 'auto' to cancel a previous override.

* DELETE /api/schedule/\<schedule_id\>

Cancel a scheduled override.

* GET /api/sensors

Return the list of available sensors.

* GET /api/sensor/\<sensor_name\>

Return the current value of the specified sensor.

* POST /api/tictac

Trigger a check of the current state and apply modification if needed.
This route is usually called by an internal timer and exposed here only for debugging purpose.

EOF
