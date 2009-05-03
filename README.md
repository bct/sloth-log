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

Edit `config.yaml`.

XXX setup git hooks
XXX setup conneg on webserver

## Use ##

Add entries to your `maruku directory` (there's an example in there) and run
`./bin/sloth`.
