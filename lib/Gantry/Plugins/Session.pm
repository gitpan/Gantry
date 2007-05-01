package Gantry::Plugins::Session;
use strict; use warnings;

use Gantry;
use Crypt::CBC;
use MIME::Base64;
use Digest::MD5 qw( md5_hex );

use base 'Exporter';
our @EXPORT = qw( 
    session_id
    session_store
    session_remove
    session_retrieve
    do_cookiecheck
);

my %registered_callbacks;

#-----------------------------------------------------------
# $class->get_callbacks( $namespace )
#-----------------------------------------------------------
sub get_callbacks {
    my ( $class, $namespace ) = @_;

    return if ( $registered_callbacks{ $namespace }++ );

    warn "Your app needs a 'namespace' method which doesn't return 'Gantry'"
            if ( $namespace eq 'Gantry' );

    return (
        { phase => 'init', callback => \&initialize }
    );
}

#-----------------------------------------------------------
# initialize
#-----------------------------------------------------------
sub initialize {
    my ($gobj) = @_;

    my $cache;
    my $cookie;
    my $session;
    my $app_rootp = $gobj->location() || '';
    my $regex     = qr/^${app_rootp}\/(cookiecheck).*/;

    return if ($gobj->uri =~ /^$regex/);

    # check to see if a previous session is active

    if (defined($session = $gobj->get_cookies('_session_id_'))) {

        # OK, store the session id

        $gobj->session_id($session);

        # load the session cache

        $gobj->cache_init() if (! $gobj->cache_inited());

    } else {

        # set a cookie and see if it works

        $session = md5_hex((md5_hex(time . {} . rand() . $$)));
        $cookie = encrypt_cookie($gobj, $session);
        $gobj->set_cookie({name => '_session_id_',
                           value => $cookie,
                           path => '/'
                          });

        $gobj->relocate($gobj->location() . '/cookiecheck');

    }

}

sub do_cookiecheck {
    my $gobj = shift;

    my $session;

    # if cookies are enabled they should be returned on the redirect

    if (defined($session = $gobj->get_cookies('_session_id_'))) {

        # Ok, redirect them back to the applicaion

        $gobj->relocate($gobj->location());

    } else {

        # Hmmm, OK, lets give them a nudge

        my $session_title = $gobj->fish_config('session_title') || 'Missing Cookies';
        my $session_wrapper = $gobj->fish_config('session_wrapper') || 'default.tt';
        my $session_template = $gobj->fish_config('session_template') || 'session.tt';

        $gobj->template_wrapper($session_wrapper);
        $gobj->stash->view->title($session_title);
        $gobj->stash->view->template($session_template);
        
    }

}

#-----------------------------------------------------------
# session_store
#-----------------------------------------------------------
sub session_store {
    my ($gobj, $key, $value) = (shift, shift, shift);

    my $session = $gobj->session_id();

    $gobj->cache_namespace($session);
    $gobj->cache_set($key, $value);

}

#-----------------------------------------------------------
# session_retrieve
#-----------------------------------------------------------
sub session_retrieve {
    my ($gobj, $key) = (shift, shift);

    my $data;
    my $session = $gobj->session_id();

    $gobj->cache_namespace($session);
    $data = $gobj->cache_get($key);

    return $data;

}

#-----------------------------------------------------------
# session_remove
#-----------------------------------------------------------
sub session_remove {
    my ($gobj, $key) = (shift, shift);

    my $session = $gobj->session_id();

    $gobj->cache_namespace($session);
    $gobj->cache_del($key);
    
}

#-----------------------------------------------------------
# session_id
#-----------------------------------------------------------
sub session_id {
    my ($gobj, $p) = (shift, shift);

    $$gobj{__SESSION_ID__} = $p if defined $p;
    return($$gobj{__SESSION_ID__});

}

#-----------------------------------------------------------
# encrypt_cookie - private method
#-----------------------------------------------------------
sub encrypt_cookie {
    my ($gobj, $session) = @_;

    local $^W = 0;     # turn off warnings

    my $secret = $gobj->fish_config('session_secret') || 'w3s3cR7';
    my $c = Crypt::CBC->new(-key     => $secret,
                            -cipher  => 'Blowfish',
                            -header  => 'none',
                            -padding => 'null');

    my $md5 = md5_hex($session);
    my $encd = $c->encrypt("$session:$md5");
    my $c_text = MIME::Base64::encode($encd, '');

    $c->finish();

    return($c_text);

}

1;

__END__

=head1 NAME

Gantry::Plugins::Session - Plugin for cookie based session management

=head1 SYNOPSIS

In Apache Perl startup or app.cgi or app.server:

    <Perl>
        # ...
        use MyApp qw{ -Engine=CGI -TemplateEngine=TT Session };
    </Perl>
    
Inside MyApp.pm:

    use Gantry::Plugins::Session;

=head1 DESCRIPTION

This plugin mixes in a method that will provide simple session management. 
Session management is done by setting a cookie to a known value. The session
cookie will only last for the duration of the browser's usage. The session
cookie can be considered an ID and for all practical purposes is an 'idiot' 
number.

Session state can be associated with the session id. The state is stored
within the session cache. Once again this is short time storage. The cache is 
periodically purged of expired items. 

Note that you must include Session in the list of imported items when you use 
your base app module (the one whose location is app_rootp). Failure to do so 
will cause errors.

=head1 CONFIGURATION

The following items can be set by configuration:

 session_secret           a plain text key used to encrypt the cookie
 session_title            a title for the session template
 session_wrapper          the wrapper for the session template
 session_template         the template for missing cookies notice

The following reasonable defaults are being used for those items:

 session_secret           same as used by Gantry::Plugins::AuthCookie.pm
 session_title            "Missing Cookies"
 session_wrapper          default.tt
 session_template         session.tt

=head1 METHODS

=over 4

=item session_id

This method returns the current session id.

 $session = $self->session_id();

=item session_store

This method will store a key/value pair within the session cache. Multiple
key/value pairs may be stored per session.

 $self->session_store('key', 'value');

=item session_retrieve

This method will retireve the stored value for a given key.

 $data = $session_retrieve('key');

=item session_remove

This method will remove the stored value for a given key.

 $session_remove('key');

=item get_callbacks

For use by Gantry.pm. Registers the callbacks needed for session management
during the PerlHandler Apache phase or its moral equivalent.

=back

=head1 PRIVATE SUBROUTINES

=over 4

=item encrypt_cookie

Encryption routine for cookie.

=item initialize

Callback to initialize plugin configuration.

=item do_cookiecheck

A URL to check to see if cookies are activated on the browser. If they
are not, then a page will be displayed prompting them to turn 'cookies' on.

=back

=head1 SEE ALSO

    Gantry

=head1 AUTHOR

Kevin L. Esteb <kesteb@wsipc.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 Kevin L. Esteb

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut
