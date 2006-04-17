package Gantry::Engine::CGI;
require Exporter;

use strict;
use Carp qw( croak );
use CGI::Simple;
use Gantry::Utils::DBConnHelper::Script;

use vars qw( @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS );

############################################################
# Variables                                                #
############################################################
@ISA 		= qw( Exporter );
@EXPORT 	= qw( 
	apache_param_hash
	apache_request
	base_server
    cgi_obj
    config
	cast_custom_error
    declined_response
    dispatch_location
	engine
    engine_init
	err_header_out
    fish_location
    fish_method
    fish_path_info
    fish_uri
    fish_user
    fish_config
    get_auth_dbh
    get_cached_config
    get_config
    get_dbh
    locations
	get_arg_hash
	header_in
	header_out
    is_status_declined
	port
    print_output
    redirect_response
	remote_ip
	send_http_header
    set_cached_config
    set_content_type
    set_no_cache
    set_req_params
	status_const
    send_error_output
    success_code
	server_root
);

@EXPORT_OK 	= qw( );
					
############################################################
# Functions                                                #
############################################################

#--------------------------------------------------
# $self->new( { locations => {..}, config => {..} } );
#--------------------------------------------------
sub new {
    my( $class, $self ) = ( shift, shift );

    bless $self, $class;

    my $config = $self->{config};

    if ( $self->{config}{ GantryConfInstance } ) {
        $config = $self->get_config(
                        $self->{config}{ GantryConfInstance },
                        $self->{config}{ GantryConfFile     },
                  );
    }

    Gantry::Utils::DBConnHelper::Script->set_conn_info(
        {
            dbconn => $config->{dbconn},
            dbuser => $config->{dbuser},
            dbpass => $config->{dbpass},
        }
    );

    Gantry::Utils::DBConnHelper::Script->set_auth_conn_info(
        {
            auth_dbconn => $config->{auth_dbconn},
            auth_dbuser => $config->{auth_dbuser},
            auth_dbpass => $config->{auth_dbpass},
        }
    );

	return $self;
	
} # end new

#--------------------------------------------------
# $self->add_config( key, value );
#--------------------------------------------------
sub add_config {
	my( $self, $key, $val ) = @_;
	$self->{cgi_obj}{config}->{$key} = $val;

} # end add_config

#--------------------------------------------------
# $self->add_location( key, value )
#--------------------------------------------------
sub add_location {
	my( $self, $key, $val ) = @_;

	$self->{locations}->{$key} = $val;

} # end add_location

#--------------------------------------------------
# $self->dispatch();
#--------------------------------------------------
sub dispatch {
	my( $self ) = @_;

    my @path = ( split( /\//, $ENV{PATH_INFO} ) );       	

	LOOP:
	while ( @path ) {

		$self->{config}->{location} = join( '/', @path );

		if ( defined $self->{locations}->{ $self->{config}->{location} } ) {
			my $mod = $self->{locations}->{ $self->{config}->{location} }; 
			
			die "module not defined for location $self->{config}->{location}"
				unless $mod;
		
			eval "use $mod";
			if ( $@ ) { die $@; }

			return $mod->handler( $self );

		}

		pop( @path );
	
	} # end while path
	
	$self->{config}->{location} = '/';
	my $mod = $self->{locations}->{ '/' }; 

	eval "use $mod" if $mod;
	if ( $@ ) { die $@; }

	return $mod->handler( $self );

} # end dispatch

#-------------------------------------------------
# Exported methods
#-------------------------------------------------


#-------------------------------------------------
# $self->cast_custom_error( error )
#-------------------------------------------------
sub cast_custom_error {
	my( $self, $error_page, $die_msg ) = @_;

	$self->send_http_header();
	$self->print_output( $error_page );

}

#-------------------------------------------------
# $self->apache_param_hash( $req )
#-------------------------------------------------
sub apache_param_hash {
	my( $self ) = @_;
	
	#my %hash_ref = $self->cgi->Vars;
	#return( \%hash_ref );	
	return( $self->cgi_obj->{params} );
	
} # end: apache_param_hash

#-------------------------------------------------
# $self->apache_request( )
#-------------------------------------------------
sub apache_request {
	my( $self, $r ) = @_;
		
} # end: apache_request

#-------------------------------------------------
# $self->base_server( $r )
#-------------------------------------------------
sub base_server {
	my( $self ) = ( shift );

	return( $ENV{HTTP_SERVER} );
	
} # end base_server

#--------------------------------------------------
# $self->cgi_obj( $hash_ref )
#--------------------------------------------------
sub cgi_obj {
	my( $self, $hash_ref ) = @_;

    if ( defined $hash_ref ) {
        $self->{cgi_obj} = $hash_ref;
    }

    return $self->{cgi_obj};
} # end cgi_obj

#--------------------------------------------------
# $self->config( $hash_ref )
#--------------------------------------------------
sub config {
	my( $self, $hash_ref ) = @_;

    if ( defined $hash_ref ) {
        $self->{cgi_obj}{config} = $hash_ref;
    }

    return $self->{cgi_obj}{config};
} # end config

#-------------------------------------------------
# $self->declined_response( )
#-------------------------------------------------
sub declined_response {
    my( $self, $action )  = @_;
	
    print $self->cgi->header(
            -type => 'text/html',
            -status => '404 Declined',
    );

    my $current_location = $self->config->{ location };

    print( $self->custom_error(
                "Declined - undefined method<br />"
                . "<span style='font-size: .8em'>"
                . "Method: $action<br />"
                . "Location: " . $current_location . "<br />"
                . "Module: " . (
                    $self->locations->{ $current_location }
                    || 'No module defined for this location' )
                . "</span>"
           )
    );
} # END declined_response

#-------------------------------------------------
# $self->dispatch_location( )
#-------------------------------------------------
sub dispatch_location {
    my $self   = shift;

    return( $ENV{ PATH_INFO }, $self->config->{location} );
} # END dispatch_location

#--------------------------------------------------
# $self->engine
#--------------------------------------------------
sub engine {
	return __PACKAGE__;
} # engine

#-------------------------------------------------
# $self->engine_init( $cgi_obj )
#-------------------------------------------------
sub engine_init {
    my $self    = shift;
    my $cgi_obj = shift;

	$cgi_obj->{params} = parse_env();

    $self->cgi_obj( $cgi_obj );
    $self->cgi( CGI::Simple->new( $cgi_obj->{params} ) );

} # END engine_init

#-------------------------------------------------
# $self->err_header_out( $header_key, $header_value )
#-------------------------------------------------
sub err_header_out {
	my( $self, $k, $v ) = @_;

} # end err_header_out

#-------------------------------------------------
# $self->fish_location( )
#-------------------------------------------------
sub fish_location {
    my $self = shift;

    my $app_rootp = $self->fish_config( 'app_rootp' );
    my $location  = $self->fish_config( 'location' );

    return $app_rootp . $location;
} # END fish_location

#-------------------------------------------------
# $self->fish_method( )
#-------------------------------------------------
sub fish_method {
    my $self = shift;

    return $ENV{ REQUEST_METHOD };
} # END fish_method

#-------------------------------------------------
# $self->fish_path_info( )
#-------------------------------------------------
sub fish_path_info {
    my $self = shift;

    return $ENV{ PATH_INFO };
} # END fish_path_info

#-------------------------------------------------
# $self->fish_uri( )
#-------------------------------------------------
sub fish_uri {
    my $self = shift;

    return $ENV{ SCRIPT_NAME } . $ENV{ PATH_INFO };
} # END fish_uri

#-------------------------------------------------
# $self->fish_user( )
#-------------------------------------------------
sub fish_user {
    my $self = shift;

    return $self->{cgi_obj}{config}{user} || $ENV{ USER };
} # END fish_user

#--------------------------------------------------
# $self->fish_config( $param )
#--------------------------------------------------
sub fish_config {
    my $self     = shift;
    my $param    = shift;

    # see if there is Gantry::Conf data
    my $conf     = $self->get_config();

    return $$conf{ $param } if ( defined $conf and defined $$conf{ $param } );

    # otherwise, look in the cgi engine object
    return $self->{cgi_obj}{config}{ $param };

}

#--------------------------------------------------
# $self->get_config
#--------------------------------------------------
sub get_config {
    my $self     = shift;
    my $instance = shift || $self->{cgi_obj}{config}{ GantryConfInstance };

    return unless defined $instance;

    my $file     = shift || $self->{cgi_obj}{config}{ GantryConfFile };

    my $conf;
    my $cached   = 0;
    my $location = $self->location;
    
    $conf        = $self->get_cached_config( $instance, $location );

    $cached++ if ( defined $conf );

    require Gantry::Conf;

    $conf      ||= Gantry::Conf->retrieve(
        {
            instance    => $instance,
            config_file => $file,
            location    => $location
        }
    );

    $self->set_cached_config( $instance, $location, $conf )
            if ( not $cached and defined $conf );

    return $conf;

} # END get_config

my %conf_cache;

sub get_cached_config {
    my $self     = shift;
    my $instance = shift;

    return $conf_cache{ $instance };
}

sub set_cached_config {
    my $self     = shift;
    my $instance = shift;
    shift;                 # not using location, this cache good for one page
    my $conf     = shift;
}

#-------------------------------------------------
# $self->get_arg_hash
#-------------------------------------------------
sub get_arg_hash {
    my( $self ) = @_;

	#my %hash_ref = $self->cgi->Vars;
	
	return( $self->cgi_obj->{params} );	
										
} # end get_arg_hash

#-------------------------------------------------
# $self->get_auth_dbh( )
#-------------------------------------------------
sub get_auth_dbh {
    Gantry::Utils::DBConnHelper::Script->get_auth_dbh;
}

#-------------------------------------------------
# $self->get_dbh( )
#-------------------------------------------------
sub get_dbh {
    Gantry::Utils::DBConnHelper::Script->get_dbh;
}

#-------------------------------------------------
# $self->header_in( )
#-------------------------------------------------
sub header_in {
	my( $self, $key ) = @_;

} # end header_in

#-------------------------------------------------
# $self->header_out( $header_key, $header_value )
#-------------------------------------------------
sub header_out {
	my( $self, $k, $v ) = @_;
		
	$self->{__HEADERS_OUT__}->{$k} = $v if defined $k;	
	return( $self->{__HEADERS_OUT__} );

} # end header_out

#--------------------------------------------------
# $self->locations( $hash_ref )
#--------------------------------------------------
sub locations {
	my( $self, $hash_ref ) = @_;

    if ( defined $hash_ref ) {
        $self->{cgi_obj}{locations} = $hash_ref;
    }

    return $self->{cgi_obj}{locations};
} # end locations

#-------------------------------------------------
# $self->redirect_response( )
#-------------------------------------------------
sub redirect_response {
    my $self = shift;

    print $self->cgi->redirect( $self->header_out->{location} );

} # END redirect_response

#-------------------------------------------------
# $self->remote_ip( $r )
#-------------------------------------------------
sub remote_ip {
	my( $self ) = ( shift, shift );
	
	return( $ENV{REMOTE_ADDR} );

} # end remote_ip

#-------------------------------------------------
# $self->print_output( $response_page )
#-------------------------------------------------
sub print_output {
    my $self          = shift;
    my $response_page = shift;

    print $response_page;

} # print_output

#-------------------------------------------------
# $self->port( $r )
#-------------------------------------------------
sub port {
	my( $self ) = ( shift );
  	
	return( $ENV{SERVER_PORT} );

} # end port

#-------------------------------------------------
# $self->server_root( $r )
#-------------------------------------------------
sub server_root {
	my( $self ) = ( shift );
	
	return( $ENV{HTTP_SERVER} );

} # end server_root

#-------------------------------------------------
# $self->status_const( 'OK | DECLINED | REDIRECT' )
#-------------------------------------------------
sub status_const {
	my( $self, $status ) = @_;

    return '404'         if uc $status eq 'DECLINED';
    return '200'         if uc $status eq 'OK';
    return '302'         if uc $status eq 'REDIRECT';
	return '403'         if uc $status eq 'FORBIDDEN';
    return '401'         if uc $status eq 'AUTH_REQUIRED';
    return '401'         if uc $status eq 'HTTP_UNAUTHORIZED';
    return '400'	     if uc $status eq 'SERVER_ERROR';

	die( "Undefined constant $status" );
	

} # end status_const

#-------------------------------------------------
# $self->is_status_declined( $status )
#-------------------------------------------------
sub is_status_declined {
    my $self = shift;

    my $status = $self->status || '';

    return 1 if ( $status eq 'DECLINED' );
} # END is_status_declined

#-------------------------------------------------
# $self->send_error_output( $@ )
#-------------------------------------------------
sub send_error_output {
    my $self     = shift;

   	print $self->cgi->header(
            -type   => 'text/html',
            -status => '500 Server Error',
   	);

    $self->do_error( $@ );
    print( $self->custom_error( $@ ) );

} # END send_error_output

#-------------------------------------------------
# $self->send_http_header( )
#-------------------------------------------------
sub send_http_header {
    my $self = shift;

    print $self->cgi->header(
            -type => $self->content_type
    );

} # send_http_header

#-------------------------------------------------
# $self->set_content_type( )
#-------------------------------------------------
sub set_content_type {


# This method is for mod_perl engines.  They need to transfer
# the content_type from the site object to the apache request object.
# We don't need to do that.

} # set_content_type

#-------------------------------------------------
# $self->set_no_cache( )
#-------------------------------------------------
sub set_no_cache {
    my $self = shift;

    $self->cgi->no_cache( 1 ) if $self->no_cache;
} # set_no_cache

#-------------------------------------------------
# $self->set_req_params( )
#-------------------------------------------------
sub set_req_params {
	my $self = shift;
	
	#my %params = $self->cgi->Vars;
	#my %params = %CGI::Deurl::query;

	$self->params( $self->cgi_obj->{params} );

} # END set_req_params

#-------------------------------------------------
# $self->success_code( )
#-------------------------------------------------
sub success_code {

# This is for mod_perl engines.  They need to tell apache that
# things went well.

} # END success_code

sub parse_env {
	my $data;
	my $hash = {};

	my $ParamSeparator = '&';

	if ( defined $ENV{REQUEST_METHOD} 
			&& $ENV{REQUEST_METHOD} eq "POST" ) {

		read STDIN , $data , $ENV{CONTENT_LENGTH} ,0;

     	if ( $ENV{QUERY_STRING} ) {
      		$data .= $ParamSeparator . $ENV{QUERY_STRING};
     	}

    } 
	elsif ( defined $ENV{REQUEST_METHOD} 
		&& $ENV{REQUEST_METHOD} eq "GET" ) {
     
		$data = $ENV{QUERY_STRING};
    } 
	elsif ( defined $ENV{REQUEST_METHOD} ) {
     	print "Status: 405 Method Not Allowed\r\n\r\n";
     	exit;
    }

    return {} unless (defined $data and $data ne '');


    $data =~ s/\?$//;
    my $i=0;

    my @items = grep {!/^$/} (split /$ParamSeparator/o, $data);
    my $thing;

    foreach $thing (@items) {

     	my @res = $thing=~/^(.*?)=(.*)$/;
     	my ( $name, $value, @value );

     	if ( $#res <= 0 ) {
      		$name  = $i++;
      		$value = $thing;
     	} 
		else {
      		( $name, $value ) = @res;
     	}
     	
     	$name =~ tr/+/ /;
     	$name =~ s/%(\w\w)/chr(hex $1)/ge;

     	$value =~ tr/+/ /;
     	$value =~ s/%(\w\w)/chr(hex $1)/ge;

     	if ( $hash->{$name} ) {
      		if ( ref $hash->{$name} ) {
       			push( @{$hash->{$name}}, $value );
      		} 
			else {
       			$hash->{$name} = [ $hash->{$name}, $value];
      		}
     	} 
		else {
      		$hash->{$name} = $value;
     	}
    }
	
	return( $hash );
}

# EOF
1;

__END__

=head1 NAME 

Gantry::Engine::CGI - CGI plugin ( or mixin )

=head1 SYNOPSIS


 use strict;
 use CGI::Carp qw(fatalsToBrowser);
 use MyApp qw( -Engine=CGI -TemplateEngine=Default );
 use Gantry::Engine::CGI;

 my $cgi = Gantry::Engine::CGI->new( {
   locations => {
     '/'        => 'MyApp',
     '/music'  => 'MyApp::Music',
   },
   config => {
      img_rootp           => '/malcolm/images',
      css_rootp           => '/malcolm/style',
      app_rootp           => '/cgi-bin/theworld.cgi',
   }
 } );

 # optional: templating variables
 $cgi->add_config( 'template_wrapper', 'wrapper.tt' );
 $cgi->add_config( 'root', '/home/httpd/templates' );
  
 # optional: database connection variables
 $cgi->add_config( 'dbconn', 'dbi:Pg:dbname=mydatabase' );
 $cgi->add_config( 'dbuser','apache' );

 # optional: add another location
 $cgi->add_location( '/music/artists', 'MyApp::Music::Artists' );
 
 # Standard CGI 
 $cgi->dispatch;   

 # Fast-CGI
 use FCGI;
 my $request = FCGI::Request();
  
 while( $request->Accept() >= 0 ) {
   $cgi->dispatch;
 }

=head1 Fast-CGI

Be sure add the nesscessary while loop around the cgi dispatch method call.

 use FCGI;
 my $request = FCGI::Request();

 while( $request->Accept() >= 0 ) {
   $cgi->dispatch;
 }

=head1 Fast-CGI and Apache

To enable Fast-CGI for Apache goto http://www.fastcgi.com/

 Alias /cgi-bin/ "/home/httpd/cgi-bin/"
 <Location /cgi-bin>
     Options +ExecCGI
     AddHandler fastcgi-script cgi
 </Location>

=head1 DESCRIPTION

This module is the binding between the Gantry framework and the CGI API.
This particluar module contains the standard CGI specific bindings. 

=head1 METHODS of this CLASS

=over 4

=item new

cgi object that can be used to dispatch request to corresonding

=item dispatch

This method dispatchs the current request to the corresponding module.

=item add_config

Adds a configuration item to the cgi object

=item add_location

Adds a location to the cgi object

=head1 METHODS MIXED into the SITE OBJECT

=item $self->base_server

Returns the physical server this connection came in 
on (main server or vhost):

=item dispatch_location

The uri tail specific to this request.  Returns:

    $ENV{ PATH_INFO }, $self->config->location

Note that this a two element list.

=item engine

Returns the name for the engine

=item fish_config

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

=item get_config

If you are using Gantry::Conf, this will return the config hash reference
for the current location.

=item get_cached_conf/set_cached_conf

These cache the Gantry::Conf config hash in a lexical hash.  Override them if
you want more persistent caching.  These are instance methods.  get
receives the invoking object, the name of the GantryConfInstance,
and the current location (for ease of use, its also in the invocant).
set receives those plus the conf hash it should cache.

=item $self->header_out( $header_key, $header_value )

Change the value of a response header, or create a new one.

=item $self->remote_ip

Returns the IP address for the remote user

=item $self->port

Returns port number in which the request came in on.

=item $self->server_root

Returns the value set by the top-level ServerRoot directive

=item $self->status_const( 'OK | DECLINED | REDIRECT' )

Get or set the reply status for the client request. The Apache::Constants 
module provide mnemonic names for the status codes.

=over 4

=back

=head1 SEE ALSO

Gantry(3)

=head1 LIMITATIONS


=head1 AUTHOR

Tim Keefer <tkeefer@gmail.com>

=head1 COPYRIGHT and LICENSE

Copyright (c) 2005-6, Tim Keefer.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut
