package Gantry::Engine::MP13;
require Exporter;

use strict;
use Carp qw( croak );

use Apache::Constants qw( DECLINED OK REDIRECT AUTH_REQUIRED 
							SERVER_ERROR FORBIDDEN );
use Apache::Request;

use Gantry::Conf;
use Gantry::Utils::DBConnHelper::MP13;

use vars qw( @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS );

############################################################
# Variables                                                #
############################################################
@ISA 		= qw( Exporter );
@EXPORT 	= qw( 
	apache_param_hash
	apache_request
	base_server
	cast_custom_error
    declined_response
    dispatch_location
	engine
    engine_init
	err_header_out
    fish_config
    fish_location
    fish_method
    fish_path_info
    fish_uri
    fish_user
	get_arg_hash
    get_auth_dbh
    get_cached_config
    get_config
    get_dbh
	header_in
	header_out
    is_status_declined
	log_error
	port
    print_output
    redirect_response
	remote_ip
	send_http_header
    send_error_output
	server_root	
    set_cached_config
    set_content_type
    set_no_cache
    set_req_params
	status_const
    success_code
);

@EXPORT_OK 	= qw( );
					
############################################################
# Functions                                                #
############################################################

#-------------------------------------------------
# $self->log_error( error )
#-------------------------------------------------
sub log_error {
    my( $self, $msg ) = @_;

    $self->r->log_error( $msg );

}

#-------------------------------------------------
# $self->cast_custom_error( error )
#-------------------------------------------------
sub cast_custom_error {
	my( $self, $error_page, $die_msg ) = @_;

	$self->r->log_error( $die_msg );
	$self->r->custom_response( 
		$self->status_const( 'FORBIDDEN' ), $error_page );
	
	return( $self->status_const( 'FORBIDDEN' ) );
}

#-------------------------------------------------
# $self->apache_param_hash( $req )
#-------------------------------------------------
sub apache_param_hash {
	my( $self, $req ) = @_;
	
	my $hash = $req->param;
		
	return( $hash );

} # end: apache_param_hash

#-------------------------------------------------
# $self->apache_request( )
#-------------------------------------------------
sub apache_request {
	my( $self, $r ) = @_;
	
	return( 
		$r ? Apache::Request->new( $r, POST_MAX => $self->post_max )
		: Apache::Request->new( $self->r, POST_MAX => $self->post_max ) );
	
} # end: apache_request

#-------------------------------------------------
# $self->base_server( $r )
#-------------------------------------------------
sub base_server {
	my( $self, $r ) = ( shift, shift );

	return( 
		$r ? $r->server->server_hostname
		: $self->r->server->server_hostname );
	
} # end base_server

#-------------------------------------------------
# $self->declined_response( )
#-------------------------------------------------
sub declined_response {
    my $self     = shift;

    return $self->status_const( 'DECLINED' );
} # END declined_response

#-------------------------------------------------
# $self->dispatch_location( )
#-------------------------------------------------
sub dispatch_location {
    my $self     = shift;

    return $self->uri, $self->location;
} # END dispatch_location

#-------------------------------------------------
# $self->engine
#-------------------------------------------------
sub engine {
	return __PACKAGE__;

} # end engine

#-------------------------------------------------
# $self->engine_init( )
#-------------------------------------------------
sub engine_init {
    my $self = shift;
    my $r    = shift;
	
    $self->r( $r );
} # END engine_init

#-------------------------------------------------
# $self->err_header_out( $key, $value ) 
#-------------------------------------------------
sub err_header_out {
	my( $self, $k, $v ) = @_;
	
	$self->r->err_header_out( $k => $v );

} # end err_header_out

#-------------------------------------------------
# $self->fish_config( $param )
#-------------------------------------------------
sub fish_config {
    my ( $self, $param ) = @_;

    # see if there is Gantry::Conf data
    my $conf     = $self->get_config();

    return $$conf{$param} if ( defined $conf and defined $$conf{$param} );
   	
    # otherwise, use dir_config for traditional approach
	return $self->r()->dir_config( $param );

} # END fish_config

#-------------------------------------------------
# $self->fish_location( )
#-------------------------------------------------
sub fish_location {
    my $self = shift;

    return $self->r()->location;
} # END fish_location

#-------------------------------------------------
# $self->fish_method( )
#-------------------------------------------------
sub fish_method {
    my $self = shift;

    return $self->r()->method;
} # END fish_method

#-------------------------------------------------
# $self->fish_path_info( )
#-------------------------------------------------
sub fish_path_info {
    my $self = shift;

    return $self->r()->path_info;
} # END fish_path_info

#-------------------------------------------------
# $self->fish_uri( )
#-------------------------------------------------
sub fish_uri {
    my $self = shift;

    return $self->r()->uri;
} # END fish_uri

#-------------------------------------------------
# $self->fish_user( )
#-------------------------------------------------
sub fish_user {
    my $self = shift;

    return $self->r()->user;
} # END fish_user

#-------------------------------------------------
# $self->get_arg_hash
#-------------------------------------------------
sub get_arg_hash {
	my( $self, $r ) = @_;
	
	my %args;
	if ( $r ) {
		%args = $r->args;
	}
	else {
		%args = $self->r->args;
	}
	
	return wantarray ? %args : \%args;

} # end get_arg_hash

#-------------------------------------------------
# $self->get_auth_dbh( )
#-------------------------------------------------
sub get_auth_dbh {
    Gantry::Utils::DBConnHelper::MP13->get_auth_dbh;
}

#-------------------------------------------------
# $self->get_config( )
#-------------------------------------------------
sub get_config {
    my ( $self, $param_name ) = @_;

    # see if there is Gantry::Conf data
    my $instance = $self->r()->dir_config( 'GantryConfInstance' );

    return unless defined $instance;

    my $file     = $self->r()->dir_config( 'GantryConfFile'     );

    my $conf;
    my $cached   = 0;
    my $location = $self->location;
    $conf        = $self->get_cached_config( $instance, $location );

    $cached++ if ( defined $conf );

    $conf ||= Gantry::Conf->retrieve(
        {
            instance    => $instance, 
            config_file => $file,
            location    => $location,
        }
    );

    $self->set_cached_config( $instance, $location, $conf )
            if ( not $cached and defined $conf );

    return $conf;
	
} # END get_config

sub get_cached_config {
    my $self     = shift;
    my $instance = shift;

    return $self->r()->pnotes( "conf_$instance" );
}

sub set_cached_config {
    my $self     = shift;
    my $instance = shift;
    shift;  # ignore location, cache for one request only
    my $conf     = shift;

    $self->r()->pnotes( "conf_$instance", $conf );
}

#-------------------------------------------------
# $self->get_dbh( )
#-------------------------------------------------
sub get_dbh {
    Gantry::Utils::DBConnHelper::MP13->get_dbh;
}

#-------------------------------------------------
# $self->header_in( $key )
#-------------------------------------------------
sub header_in {
	my( $self, $key ) = @_;
	
	return $self->r->header_in($key);

} # end header_in

#-------------------------------------------------
# $self->header_out( $header_key, $header_value )
#-------------------------------------------------
sub header_out {
	my( $self, $k, $v ) = @_;
	
	$self->r->header_out( $k => $v );	

} # end header_out

#-------------------------------------------------
# $self->is_status_declined( $status )
#-------------------------------------------------
sub is_status_declined {
    my $self = shift;

    my $status = $self->status || '';

    return 1 if ( $status eq $self->status_const( 'DECLINED' ) );
} # END is_status_declined

#-------------------------------------------------
# $self->port( $r ) - NOT TIED TO API YET
#-------------------------------------------------
sub port {
	my( $self, $r ) = ( shift, shift );
		
	return( '' );
	
} # end port

#-------------------------------------------------
# $self->print_output( )
#-------------------------------------------------
sub print_output {
    my $self     = shift;
    my $response = shift;

    $self->r()->print( $response );
} # END print_output

#-------------------------------------------------
# $self->redirect_response( )
#-------------------------------------------------
sub redirect_response {
    my $self     = shift;

    return $self->status_const( 'REDIRECT' );
} # END redirect_response

#-------------------------------------------------
# $self->remote_ip( $r )
#-------------------------------------------------
sub remote_ip {
	my( $self, $r ) = @_;

	return( 
		$r ? $r->connection->remote_ip
		: $self->r->connection->remote_ip );

} # end remote_ip

#-------------------------------------------------
# $self->send_error_output( $@ )
#-------------------------------------------------
sub send_error_output {
    my $self     = shift;

    $self->do_error( $@ );
    return( $self->custom_error( $@ ) );

} # END send_error_output

#-------------------------------------------------
# $self->send_http_header( )
#-------------------------------------------------
sub send_http_header {
	my( $self ) = @_;
	
	$self->r->send_http_header; 

} # end send_http_header

#-------------------------------------------------
# $self->server_root( $r ) - NOT TIED TO API YET
#-------------------------------------------------
sub server_root {
	my( $self, $r ) = ( shift, shift );

	return('');
	
} # end server_root

#-------------------------------------------------
# $self->set_content_type( )
#-------------------------------------------------
sub set_content_type {
    my $self = shift;

    $self->r()->content_type( $self->content_type );
} # END set_content_type

#-------------------------------------------------
# $self->set_no_cache( )
#-------------------------------------------------
sub set_no_cache {
    my $self = shift;

    $self->r()->no_cache( 1 ) if ( $self->no_cache );
} # END set_no_cache

#-------------------------------------------------
# $self->set_req_params( )
#-------------------------------------------------
sub set_req_params {
    my $self = shift;

    $self->ap_req( $self->apache_request( $self->r ) );
    $self->params( $self->apache_param_hash( $self->ap_req ) );

} # END set_req_params

#-------------------------------------------------
# $self->status_const( 'OK | DECLINED | REDIRECT' )
#-------------------------------------------------
sub status_const {
	my( $self, $status ) = @_;
	
	return DECLINED  		if uc $status eq 'DECLINED';
	return OK		 		if uc $status eq 'OK';
	return REDIRECT  		if uc $status eq 'REDIRECT'; 
	return FORBIDDEN 		if uc $status eq 'FORBIDDEN'; 
	return AUTH_REQUIRED 	if uc $status eq 'AUTH_REQUIRED';
	return AUTH_REQUIRED 	if uc $status eq 'HTTP_UNAUTHORIZED';
	return SERVER_ERROR 	if uc $status eq 'SERVER_ERROR';

	die( "Undefined constant $status" );

} # end status_const

#-------------------------------------------------
# $self->success_code( )
#-------------------------------------------------
sub success_code {
    my $self = shift;

    return $self->status_const( 'OK' );
} # END success_code

# EOF
1;

__END__

=head1 NAME

Gantry::Engine::MP13 - mod_perl 1.0 plugin ( or mixin )

=head1 SYNOPSIS

  use Gantry::Engine::MP13;


=head1 DESCRIPTION

This module is the binding between the Gantry framework and the mod_perl API.
This particluar module contains the mod_perl 1.0 specific bindings.

See mod_perl documentation for a more detailed description for some of these
bindings.

=head1 METHODS

=over 4

=item $self->apache_param_hash

Return a hash reference to the apache request body parameters.

=item $self->apache_request

Apache::Request is a subclass of the Apache class, which adds methods
for parsing GET requests and POST requests where Content-type is one of
application/x-www-form-urlencoded or multipart/form-data. See the
libapreq(3) manpage for more details.

=item $self->base_server

Returns the physical server this connection came in
on (main server or vhost):

=item dispatch_location

The uri tail specific to this request.  Returns:

    $self->uri, $self->location

Note that this is a two element list.

=item $self->engine

Returns the name of the engine, i.e. Gantry::Engine::MP13

=item $self->engine_init

Receives the request object and stores it in the site object.  Returns
nothing useful.

=item $self->err_header_out

The $r->err_headers_out method will return a %hash of server response
headers. This can be used to initialize a perl hash, or one could use
the $r->err_header_out() method (described below) to retrieve or set a
specific header value directly

See mod_perl docs.

=item fish_conf

Pass this method the name of a conf parameter you need.  Returns the
value for the parameter.

=item fish_location

Returns the location for the current request.

=item fish_method

Returns the HTTP method of the current request.

=item fish_path_info

Returns the path info for the current request.

=item fish_uri

Returns the uri for the current request.

=item fish_user

Returns the currently logged-in user.

=item $self->get_arg_hash

    returns a hash of url arguments.

    /some/where?arg1=don&arg2=johnson

=item $self->get_auth_dbh

Same as get_dbh, but for the authentication database.

=item get_config

If you are using Gantry::Conf, this will return the config hash reference
for the current location.

=item get_cached_conf/set_cached_conf

These cache the Gantry::Conf config hash in pnotes.  Override them if
you want more persistent caching.  These are instance methods.  get
receives the invoking object, the name of the GantryConfInstance,
and the current location (for ease of use, its also in the invocant).
set receives those plus the conf hash it should cache.

=item $self->get_dbh

Returns the current regular database connection if one is available or
undef otherwise.

=item $self->header_in

The $r->headers_in method will return a %hash of client request headers.
This can be used to initialize a perl hash, or one could use the
$r->header_in() method (described below) to retrieve a specific header
value directly.

See mod_perl docs.

=item $self->header_out( $r, $header_key, $header_value )

Change the value of a response header, or create a new one.

=item $self->log_error( message )

Writes message to the apache web server log

=item $self->port

Returns port number in which the request came in on.

=item $self->print_output( $response_page )

This method sends the contents of $response page back to apache.  It
uses the print method on the request object.

=item $self->remote_ip

Returns the IP address for the remote user

=item $self->send_http_header( $r )

Send the response line and all headers to the client. Takes an optional
parameter indicating the content-type of the response, i.e. 'text/html'.

This method will create headers from the $r->content_xxx() and $r->no_cache() 
attributes (described below) and then append the headers defined by 
$r->header_out (or $r->err_header_out if status indicates an error).

See mod_perl 1.0 docs.

=item $self->server_root

Returns the value set by the top-level ServerRoot directive

=item $self->set_content_type()

Sets the content type stored in the site object's content_type attribute
on the apache request object.

=item $self->set_no_cache

Sets the no_cache flag in the apache request object with the value
for no_cache in the site object.

=item set_req_params

Sets up the apreq object and the form parameters from it.

=item $self->status_const( 'OK | DECLINED | REDIRECT' )

Get or set the reply status for the client request. The Apache::Constants
module provide mnemonic names for the status codes.

=over 4

=back

=head1 SEE ALSO

mod_perl(3), Gantry(3) 

=head1 LIMITATIONS


=head1 AUTHOR

Tim Keefer <tkeefer@gmail.com>

=head1 COPYRIGHT and LICENSE

Copyright (c) 2005-6, Tim Keefer.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut
