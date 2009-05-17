# sloth-log #

sloth-log is a Maruku -> Atom -> (X)HTML static file generator. It takes a
directory full of Maruku files (or plain XML Atom entries), and turns
them into something that you can dump onto a web server.

The idea is that you `git clone` this template repository and set up a hook
so that when your new repository gets a commit or a push everything gets
updated.

## Requirements ##

- atom-tools
- maruku
- ruby-xslt
- a webserver that supports content negotiation

## Setup ##

    # make a new remote repository 'foo'
    server$ mkdir foo; cd foo; git init

    # add a remote repository named 'site' and push the basics to it
    laptop$ git remote add site server:foo
    laptop$ git push site master

    # install the post-receive hook and configure sloth-log
    server$ git checkout
    server$ cp bin/post-update .git/hooks/
    server$ $EDITOR config.yaml

    # test the configuration
    server$ ./bin/sloth
    # check that it all went as expected
    server$ git commit config.yaml

    # add a new entry and publish it
    laptop$ $EDITOR entries/hello-world; git commit
    laptop$ git push site master

## Content Negotiation ##

In order for any of the generated links to work, your server needs to support
content negotiation for Atom and (X)HTML.

### Conneg with Lighttpd ###

Lighttpd itself doesn't support content negotiation. It does support Lua though,
and you can get conneg that way.

[Michael Gorven][] has generously provided a script that is included with sloth-log.
To install it, just copy bin/negotiate.lua somewhere and add this line to your
lighttpd.conf:

    magnet.attract-physical-path-to = ("somewhere/negotiate.lua")

Your /etc/mime.types should contain entries that map '.atom' =>
`application/atom+xml` and '.xhtml' => `application/xhtml+xml`.

There is [another Lua Lighttpd content negotiation script][lighttpd-conneg-2]
that may be easier to set up and faster to respond; I haven't tried it.

## Use ##

Add Maruku entries to ./entries (there should already be an example in there).
When you're ready to publish, commit your changes and `git push site`.

If you don't want to deal with all of the `post-update` hook nonsense, you can
just run `./bin/sloth` to generate the HTML.

[Michael Gorven]: http://github.com/bct/sloth-log/tree/master
[lighttpd-conneg-2]: http://redmine.lighttpd.net/projects/lighttpd/wiki/MigratingFromApache#MultiViews
