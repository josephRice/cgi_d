# cgi_d testing application

### Build instructions 
from the project root.  run:

```
$ dub build -c test_app
```

this will create the cgi_d_test.cgi in the project root ./example/cgi-bin

### Installation
*Using Apache2 installed on Ubuntu 16.04* - setting up apache2 is beyond the scope of this documentation.

From the project root folder run the following.

```
$ cd ./example

$ export WORKING_DIR=`pwd`

$ sudo echo $WORKING_DIR

$ sudo mkdir /var/www/cgi-bin

$ sudo ln -s $WORKING_DIR/cgi-bin /var/www/cgi-bin/cgi_d_test

$ sudo cp $WORKING_DIR/apache2_conf/cgi_d_test.conf /etc/apache2/conf-available/

$ sudo a2enmod cgi

$ sudo a2enconf cgi_d_test

$ sudo service apache2 reload
```

### Testing


curl examples for posting a file since there is no form displayed replace <..> with approprate values

```
$ curl -F test=123 -F test=another_test -F test="this is a Third Test" -F bob=1 -F file=@./<some file you have> -F file=@./<some other file you have> "http://localhost/cgi_d/cgi_d_test.cgi"

$ curl -F test=123 -F test=another_test -F test="this is a Third Test" -F bob=1 -F file=@./<some file you have> -F file=@./<some other file you have> "http://localhost/cgi_d/cgi_d_test.cgi/repeat/a/file"
```
Other wise point your browser to
 
* [http://localhost/cgi_d/cgi_d_test.cgi](http://localhost/cgi_d/cgi_d_test.cgi) and play with the paths
* [http://localhost/cgi_d/cgi_d_test.cgi/stream/](http://localhost/cgi_d/cgi_d_test.cgi/stream/)
* [http://localhost/cgi_d/cgi_d_test.cgi?test=123&test=another_test&test=this+is+a+Third+Test&bob=1](http://localhost/cgi_d/cgi_d_test.cgi?test=123&test=another_test&test=this+is+a+Third+Test&bob=1)
