package Gantry::Docs::QuickStart;

=head1 Name

Gantry::Docs::QuickStart - Getting your first Gantry app up and running

=head1 A Simple Greeting

All you need for a gantry app is a module which uses Gantry and has
a method called do_something (usually do_main is a good first choice):

    package HiWorld;
    use strict; use warnings;

    use base 'Gantry';

    sub do_main {
        my $self = shift;

        return "Hello, Rob";
    }

    1;

I'll store this module in /home/myhome/lib/HiWorld.pm.  I'll need
to set that lib path with a use lib below.

=head1 Stand Alone Server Deployment

If you have HTTP::Server::Simple installed, you may choose to deploy
your application through it.  This is useful for kick starting development.
See below for more permanent means of deployment.

A stand alone Gantry application is an executable script which leverages
Gantry::Server (which in turn uses HTTP::Server::Simple.  This one
is enough for our small demo:

    #!/usr/bin/perl
    use strict;

    use Gantry::Server;

    use lib '/home/myhome/lib';

    use HiWorld qw{ -Engine=CGI -TemplateEngine=Default };

    my $cgi = Gantry::Engine::CGI->new();

    $cgi->add_location( '/', 'HiWorld' );

    my $server = Gantry::Server->new();
    # pass a port number to the above constructor if you don't want 8080.

    $server->set_engine_object( $cgi );
    $server->run();

=head1 CGI Deployment

To deploy this you need to choose either mod_perl or CGI.  First, I'll use
CGI -- see below for mod_perl.  Create the following script in a servable
cgi-bin directory (remember to make sure it is executable):

    #!/usr/bin/perl
    use strict;

    use CGI::Carp qw( fatalsToBrowser);

    use lib '/home/myhome/lib';

    use HiWorld qw{ -Engine=CGI -TemplateEngine=Default };

    my $cgi = Gantry::Engine::CGI->new();

    $cgi->add_location( '/', 'HiWorld' );

    $cgi->dispatch();

Then point your browser to the script.

=head1 mod_perl Deployment

To use mod_perl, you must have access to modify the httpd.conf for your
web server and to restart that server.  Here is the virtual host I created
for the greeting application:

    <VirtualHost hiworld.devel.example.com>

        ServerName   hiworld.devel.example.com
        DocumentRoot /home/myhome/html/play
        CustomLog    /home/myhome/logs/combined.log combined
        ErrorLog     /home/myhome/logs/hiworld.err

        Include /home/myhome/html/play/hiworld.conf

    </VirtualHost>

Of course, throws the real config work to hiworld.conf.  Mine assumes
mod_perl 1.3.  Here it is:

    <Perl>
        #!/usr/bin/perl

        use lib '/home/pcrow/srcgantry/play';

        use HiWorld qw{ -Engine=MP13 -TemplateEngine=Default };
    </Perl>

    <Location /hello>
        SetHandler  perl-script
        PerlHandler HiWorld
    </Location>

After restarting the server, I can point my browser to

    http://hiworld.devel.example.com/hello

to see the greeting.

If you are using mod_perl 2, simply change the use statement to:

        use HiWorld qw{ -Engine=MP20 -TemplateEngine=Default };

(i.e. replace MP13 with MP20)

Note that if other Gantry apps are running in the same server instance,
they may fight over which template engine to use.  Generally, the
first app to put in a use statement for its base module chooses the
template engine.  We don't mind this since we always use TT.  Even after
you have chosen TT, you can turn it off by adding these statements
to the top of your do_* method.

    $self->content_type( 'text/xml' );
    $self->template_disable( 1 );

=head1 Further Reading

For a bigger example, see Gantry::Docs::Tutorial which walks through
building a simple database-backed app from scratch.

=head1 Author

Phil Crow <philcrow2000@yahoo.com>

=head1 Copyright and License

Copyright (c) 2006, Phil Crow.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut
