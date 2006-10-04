package Gantry;

use strict;
use Gantry::Stash;
use Gantry::Init;
use CGI::Simple;
use File::Spec;
use POSIX qw( strftime );

############################################################
# Variables                                                #
############################################################
our $VERSION = '3.41';
our $DEFAULT_PLUGIN_TEMPLATE = 'Gantry::Template::Default';
our $CONF;

############################################################
# Functions                                                #
############################################################

#-------------------------------------------------
# $self->handler( $r );
#-------------------------------------------------
sub handler : method {
    my $class       = shift;
    my $r_or_cgi    = shift;
    my $self        = bless( {}, $class );

    # Create the stash object
    $self->make_stash();

    # die if we don't know the engine
    if ( ! $self->can( 'engine' ) ) {
        die( 'No engine specified, engine required' );
    }
    
    my $action;
    eval {                              
        $self->init( $r_or_cgi );

        my @p       = $self->cleanroot( $self->dispatch_location );
        my $p1      = ( shift( @p ) || 'main' );
        $action     = 'do_'. $p1;

        # Do action if valid
        if ( $self->can( $action ) ) {  
            $self->do_action( $action, @p );
            $self->cleanup( );  # Cleanup.
        }
        
        # Try default action
        elsif ( $self->can( 'do_default' ) ) {
            $self->do_action( 'do_default', $p1, @p );
            $self->cleanup( );
        }
        
        # Else return declined
        else {
            $self->declined( 1 );
        }
        
        $self->declined( 1 ) if ( $self->is_status_declined( ) );

    };

    # Return REDIRECT
    return $self->redirect_response() if ( $self->redirect );
    
    # Return DECLINED
    return $self->declined_response( $action ) if ( $self->declined );
        
    # Call do_error and Return 
    if( $@ ) {
        return( $self->cast_custom_error( $self->custom_error( $@ ), $@ ) );
    }

    # set http headers
    $self->set_content_type();
    $self->set_no_cache();

    # Call do_process, defined within the template plugin
    eval {
        my $response_page =  $self->do_process( );
            
        #$self->content_length( length( $response_page ) );
        
        # call engine plugin to send headers 
        $self->send_http_header( );
        $self->print_output( $response_page );
    };

    if( $@ ) {
        $self->do_error( $@ );
        return( $self->cast_custom_error( $self->custom_error( $@ ), $@ ) );
    }
    
    # Return OK
    return $self->success_code;
    
} # end handler

#-------------------------------------------------
# $self->make_stash( )
#-------------------------------------------------
sub make_stash {
    my $self = shift;

    $self->{__STASH__} = stash->new();

} # end make_stash

#-------------------------------------------------
# $self->stash( )
#-------------------------------------------------
sub stash {
    my $self = shift;

    $self->{__STASH__} = stash->new() unless defined $self->{__STASH__};

    return $self->{__STASH__};

} # end stash

#-------------------------------------------------
# $self->declined( value )
#-------------------------------------------------
sub declined {
    my ( $self, $p ) = ( shift, shift );

    $$self{__DECLINED__} = $p if defined $p;
    return( $$self{__DECLINED__} ); 
    
} # end declined

#-------------------------------------------------
# $self->redirect( value )
#-------------------------------------------------
sub redirect {
    my ( $self, $p ) = ( shift, shift );

    $$self{__REDIRECT__} = $p if defined $p;
    return( $$self{__REDIRECT__} );
    
} # end redirect

#-------------------------------------------------
# $self->status( value )
#-------------------------------------------------
sub status {
    my ( $self, $p ) = ( shift, shift );

    $$self{__STATUS__} = $p if defined $p;
    return( $$self{__STATUS__} );
    
} # end status

#-----------------------------------------------------------------
# $self->smtp_host( value )
#-----------------------------------------------------------------
sub smtp_host {
    my ( $self, $p ) = @_;

    $$self{__SMTP_HOST__} = $p if defined $p;
    return( $$self{__SMTP_HOST__} );

} # end smtp_host

#-------------------------------------------------
# $self->relocate( $location )
#-------------------------------------------------
sub relocate {
    my ( $self, $location ) = ( shift, shift );

    $location = $self->location if ( ! defined $location );
    $self->redirect( 1 ); # Tag it for the handler to handle nice.
    $self->header_out( 'location', $location );
    $self->status( $self->status_const( 'REDIRECT' ) );
    
    return( $self->status_const( 'REDIRECT' ) );
    
} # end relocate 

#-------------------------------------------------
# $self->get_cookies
#-------------------------------------------------
sub get_cookies {
    my ( $self, $want_cookie ) = ( shift, shift );

    my $client = 
        $self->header_in( 'Cookie' ) || $self->header_in( 'HTTP_COOKIE' ); 
    
    return () if ( ! defined $client ); #|| ! $raw ); 
    
    my %cookies; 

    for my $crumb ( split ( /; /, $client ) ) { 
        my ( $key, $value ) = split( /=/, $crumb ); 
        $cookies{$key} = $value;
    } 
    
    if ( defined $want_cookie ) {
        return( $cookies{$want_cookie} );
    }
    else {
        return( \%cookies );
    }
    
} # end get_cookies

#-------------------------------------------------
# set_cookie( { @options } )
#   name => cookie name
#   value => cookie value 
#   expire => cookie expires
#   path => cookie path
#   domain => cookie domain
#   secure => [0/1] cookie secure
#-------------------------------------------------
sub set_cookie {
    my ( $self, @opts ) = @_; 
    
    my $options = (@opts == 1) && UNIVERSAL::isa($opts[0], 'HASH')
        ? shift(@opts) : { @opts }; 
        
    croak( 'Cookie has no name' )   if ( ! defined $$options{name} );   
    croak( 'Cookie has no value' )  if ( ! defined $$options{value} );  

    # Only required fields in the cookie.
    my $cookie = sprintf( "%s=%s; ", $$options{name}, $$options{value} );



    $cookie .= sprintf( "path=%s; ", $$options{path} )  
        if ( defined $$options{path} );
    $cookie .= sprintf( "domain=%s; ", $$options{domain} )  
        if ( defined $$options{domain} );
    $cookie .= 'secure' 
        if ( defined $$options{secure} && $$options{secure} );

    # these are all optional. and should be created as such.
    if ( defined $$options{expire} ) {
        $$options{expire} = 0 if ( $$options{expire} !~ /^\d+$/ );
        $cookie .= strftime(    "expires=%a, %d-%b-%Y %H:%M:%S GMT; ", 
                                gmtime( time + $$options{expire} ) );
    }

    $cookie =~ s/\;\s*$/ /;

    $self->err_header_out( 'Set-Cookie', $cookie ); # mp13 mp20
    $self->cookie_stash( $cookie ); # cgi

    return();
    
} # end set_cookies

sub cookie_stash {
    my ( $self, $p ) = @_;

    $self->{__COOKIE_STASH__} = [] 
        unless defined $self->{__COOKIE_STASH__};
    
    if ( defined $p ) {
        push( @{ $self->{__COOKIE_STASH__} }, $p );
    }
    return( $self->{__COOKIE_STASH__} );
        
} # end method
     
sub response_headers {
    my ( $self, $key, $value ) = @_;

    $self->{__RESPONSE_HEADERS__} = {} 
        unless defined $self->{__RESPONSE_HEADERS__};
    
    if ( defined $key ) {
        $self->{__RESPONSE_HEADERS__}{ $key } = $value;
    }
    return( $self->{__RESPONSE_HEADERS__} );
        
} # end method

#-------------------------------------------------
# $self->cleanroot( $uri, $root )
#-------------------------------------------------
sub cleanroot {
    my ( $self, $uri, $root ) = @_;

    $uri =~ s!^$root!!g;
    $uri =~ s/\/\//\//g;
    $uri =~ s/^\///;

    return( split( '/', $uri ) );
    
} # end cleanroot

#-------------------------------------------------
# $self->import( $self, @options )
#-------------------------------------------------
sub import {
    my ( $class, @options ) = @_;

    my( $engine, $tplugin, $plugin, $conf_instance, $conf_file );
    
    foreach (@options) {
        
        # Import the proper engine
        if ( /^-Engine=(\S+)/ ) { 
            $engine = "Gantry::Engine::$1";
            my $engine_file = File::Spec->catfile( 
                'Gantry', 'Engine', "${1}.pm" 
            );

            eval {
                require $engine_file;
                import $engine;
            };
            if ( $@ ) { die qq/Could not load engine "$engine", "$@"/ }
        }
        
        # Load Template Engine
        elsif ( /^-TemplateEngine=(\S+)/ ) {
            $tplugin = "Gantry::Template::$1";
            my $tfile   = File::Spec->catfile( 
                'Gantry', 'Template', "${1}.pm" 
            );

            eval {
                require $tfile;
                import $tplugin;
            };
            if ($@) { die qq/Could not load plugin "$tplugin", "$@"/ }
        }
    
        else {
            $plugin = "Gantry::Plugins::$_";
            my $plugin_file = File::Spec->catfile( 
                'Gantry', 'Plugins', "${_}.pm" 
            );

            eval {
                 require $plugin_file;
                 import $plugin;
            };
            if ($@) { die qq/Could not load plugin "$plugin", "$@"/ }
        
        }
    }
    
    # Load Default template plugin if one hasn't been defined
    if ( ! $tplugin && ! $class->can( 'do_action' ) ) {
        my( $tengine ) = ( $DEFAULT_PLUGIN_TEMPLATE =~ m!::(\w+)$! );
        my $def_tengine_file = File::Spec->catfile( 
            'Gantry', 'Template', "${tengine}.pm" 
        );

        eval {
            require $def_tengine_file;
            import $DEFAULT_PLUGIN_TEMPLATE;
        };
        if ($@) { die qq/Could not load Default template engine, "$@"/ }
        
    }   

}
#-------------------------------------------------
# $site->init( $r )
# note: this function should be redefined in the application.
# This will act as the default but it's recommended
# that only global init rules are defined here
# 
# application note: for "proper" or suggested practice,
# the application level init function should immeadiatly
# call:
#
# $site->SUPER::init( $r );
#
# After the call to SUPER, the application level init 
# should include its init intructions.
#-------------------------------------------------
sub init {
    my ( $self, $r_or_cgi ) = @_; 

    $self->engine_init( $r_or_cgi );

    # set post_max - used for apache request object
    $self->post_max( $self->fish_config( 'post_max' ) || '20000000' );

    $self->uri( $self->fish_uri() );
    $self->location( $self->fish_location() );
    $self->path_info( $self->fish_path_info() );
    $self->method( $self->fish_method() );

    # set user varible
    $self->user( $self->fish_user() );
    
    # set default content-type
    $self->content_type( $self->fish_config( 'content_type' ) || 'text/html' );

    # set template variables
    $self->template( $self->fish_config( 'template' ) );
    $self->template_default( $self->fish_config( 'template_default' ) );
    $self->template_wrapper( $self->fish_config( 'template_wrapper' ) );
    $self->template_disable( $self->fish_config( 'template_disable' ) );
    
    # set application directory variables
    my $app_root = $self->fish_config( 'root' );

    $self->root( join ':', $app_root, Gantry::Init::base_root() );
    $self->css_root( $self->fish_config( 'css_root' ) );
    $self->img_root( $self->fish_config( 'img_root' ) );
    $self->tmp_root( $self->fish_config( 'tmp_root' ) );
    
    # set application uri variables
    $self->web_rootp( $self->fish_config( 'web_rootp' ) );
    $self->app_rootp( $self->fish_config( 'app_rootp' ) );
    $self->img_rootp( $self->fish_config( 'img_rootp' ) );
    $self->css_rootp( $self->fish_config( 'css_rootp' ) );
    $self->tmp_rootp( $self->fish_config( 'tmp_rootp' ) );
    $self->editor_rootp( $self->fish_config( 'editor_rootp' ) );

    # set no cache
    $self->no_cache( $self->fish_config( 'no_cache' ) );
    
    $self->status( "" ); # to avoid uninitialized value warning

    # set page title
    $self->page_title( $self->fish_config( 'page_title' ) || $self->uri );
    
    # set default date format
    $self->date_fmt( $self->fish_config( 'date_fmt' ) || '%b %d, %Y' );
    
    
    # set request body paramater variables
    $self->set_req_params();

    # set protocol
    $self->protocol( $ENV{HTTPS} ? 'https://' : 'http://' );

    # database and auth database variables are handled in each engine's
    # Gantry::Utils::DBConnHelper::* sublcass.
    
} # END $site->init

#-------------------------------------------------
# $self->r( value )
#-------------------------------------------------
sub r {
    my ( $self, $p ) = @_;

    $self->{__R__} = $p if ( defined $p );
    return( $self->{__R__} );
        
} # end r

#-------------------------------------------------
# $self->cgi( value )
#-------------------------------------------------
sub cgi {
    my( $self, $p ) = @_;

    $self->{__CGI__} = $p if ( defined $p );
    return( $self->{__CGI__} );
} # end cgi

#-------------------------------------------------
# $self->method( value )
#-------------------------------------------------
sub method {
    my ( $self, $p ) = @_;

    $self->{__METHOD__} = $p if ( defined $p );
    return( $self->{__METHOD__} );
        
} # end method

#-------------------------------------------------
# $self->no_cache( value )
#-------------------------------------------------
sub no_cache {
    my ( $self, $p ) = @_;

    $self->{__NO_CACHE__} = $p if ( defined $p );
    return( $self->{__NO_CACHE__} );
        
} # end no_cache

#-------------------------------------------------
# $self->uri( value )
#-------------------------------------------------
sub uri {
    my ( $self, $p ) = @_;

    $self->{__URI__} = $p if ( defined $p );
    return( $self->{__URI__} || '' );
        
} # end uri

#-------------------------------------------------
# $self->location( value )
#-------------------------------------------------
sub location {
    my ( $self, $p ) = @_;

    $self->{__LOCATION__} = $p if ( defined $p );
    return( $self->{__LOCATION__} || '' );
        
} # end location

#-------------------------------------------------
# $self->current_url( )
#-------------------------------------------------
sub current_url {
    my ( $self ) = @_;

    return $self->protocol . $self->base_server . $self->uri;
} # end location

#-------------------------------------------------
# $self->path_info( value )
#-------------------------------------------------
sub path_info {
    my ( $self, $p ) = @_;

    $self->{__PATH_INFO__} = $p if ( defined $p );
    return( $self->{__PATH_INFO__} || '' );
        
} # end path_info

#-------------------------------------------------
# $self->content_length( value )
#-------------------------------------------------
sub content_length {
	my ( $self, $p ) = @_;

	$self->{__CONTENT_LENGTH__} = $p if ( defined $p );
	return( $self->{__CONTENT_LENGTH__} );
		
} # end content_length

#-------------------------------------------------
# $self->content_type( value )
#-------------------------------------------------
sub content_type {
    my ( $self, $p ) = @_;

    $self->{__CONTENT_TYPE__} = $p if ( defined $p );
    return( $self->{__CONTENT_TYPE__} );
        
} # end content_type

#-------------------------------------------------
# $self->template( value )
#-------------------------------------------------
sub template {
    my ( $self, $p ) = @_;

    $self->{__TEMPLATE__} = $p if ( defined $p );
    return( $self->{__TEMPLATE__} );
        
} # end template

#-------------------------------------------------
# $self->template_default( value )
#-------------------------------------------------
sub template_default  {
    my ( $self, $p ) = @_;

    $self->{__TEMPLATE_DEFAULT__} = $p if ( defined $p );
    return( $self->{__TEMPLATE_DEFAULT__} );
        
} # end template_default

#-------------------------------------------------
# $self->template_wrapper( value )
#-------------------------------------------------
sub template_wrapper {
    my ( $self, $p ) = @_;

    $self->{__TEMPLATE_WRAPPER__} = $p if ( defined $p );
    return( $self->{__TEMPLATE_WRAPPER__} );
        
} # end template_wrapper

#-------------------------------------------------
# $self->template_disable( value )
#-------------------------------------------------
sub template_disable {
    my ( $self, $p ) = @_;

    $self->{__TEMPLATE_DISABLE__} = $p if ( defined $p );
    return( $self->{__TEMPLATE_DISABLE__} );
        
} # end template_disable

#-------------------------------------------------
# $self->root( value )
#-------------------------------------------------
sub root {
    my ( $self, $p ) = @_;

    $self->{__ROOT__} = $p if ( defined $p );
    return( $self->{__ROOT__} || '' );
        
} # end root

#-------------------------------------------------
# $self->css_root( value )
#-------------------------------------------------
sub css_root {
    my ( $self, $p ) = @_;

    $self->{__CSS_ROOT__} = $p if ( defined $p );
    return( $self->{__CSS_ROOT__} || '' );
        
} # end css_root

#-------------------------------------------------
# $self->tmp_root( value )
#-------------------------------------------------
sub tmp_root {
    my ( $self, $p ) = @_;

    $self->{__TMP_ROOT__} = $p if ( defined $p );
    return( $self->{__TMP_ROOT__} || '' );

} # end tmp_root

#-------------------------------------------------
# $self->tmp_rootp( value )
#-------------------------------------------------
sub tmp_rootp {
    my ( $self, $p ) = @_;

    $self->{__TMP_ROOTP__} = $p if ( defined $p );
    return( $self->{__TMP_ROOTP__} || '' );

} # end tmp_rootp

#-------------------------------------------------
# $self->editor_rootp( value )
#-------------------------------------------------
sub editor_rootp {
    my ( $self, $p ) = @_;

    $self->{__EDITOR_ROOTP__} = $p if ( defined $p );
    return( $self->{__EDITOR_ROOTP__} || '' );

} # end editor_rootp

#-------------------------------------------------
# $self->img_root( value )
#-------------------------------------------------
sub img_root {
    my ( $self, $p ) = @_;

    $self->{__IMG_ROOT__} = $p if ( defined $p );
    return( $self->{__IMG_ROOT__} || '' );
        
} # end img_root

#-------------------------------------------------
# $self->app_rootp( value )
#-------------------------------------------------
sub app_rootp {
    my ( $self, $p ) = @_;

    if ( defined $p ) {
        # trim trailing slashes
        $p =~ s{/+$}{}g;

        $self->{__APP_ROOTP__} = $p;
    }
    return( $self->{__APP_ROOTP__} || '' );
        
} # end app_rootp

#-------------------------------------------------
# $self->web_rootp( value )
#-------------------------------------------------
sub web_rootp {
    my ( $self, $p ) = @_;

    $self->{__WEB_ROOTP__} = $p if ( defined $p );
    return( $self->{__WEB_ROOTP__} || '' );
        
} # end web_rootp

#-------------------------------------------------
# $self->img_rootp( value )
#-------------------------------------------------
sub img_rootp {
    my ( $self, $p ) = @_;

    if ( defined $p ) {
        # trim trailing slashes
        $p =~ s{/+$}{}g;

        $self->{__IMG_ROOTP__} = $p;
    }
    return( $self->{__IMG_ROOTP__} || '' );
        
} # end img_rootp

#-------------------------------------------------
# $self->css_rootp( value )
#-------------------------------------------------
sub css_rootp {
    my ( $self, $p ) = @_;

    if ( defined $p ) {
        # trim trailing slashes
        $p =~ s{/+$}{}g;

        $self->{__CSS_ROOTP__} = $p;
    }
    return( $self->{__CSS_ROOTP__} || '' );
        
} # end css_rootp

#-------------------------------------------------
# $self->page_title( value )
#-------------------------------------------------
sub page_title {
    my ( $self, $p ) = @_;

    $self->{__PAGE_TITLE__} = $p if ( defined $p );
    return( $self->{__PAGE_TITLE__} || '' );
        
} # end uri

#-------------------------------------------------
# $self->date_fmt( value )
#-------------------------------------------------
sub date_fmt {
    my ( $self, $p ) = @_;

    $self->{__DATE_FMT__} = $p if ( defined $p );
    return( $self->{__DATE_FMT__} );
        
} # end date_fmt

#-------------------------------------------------
# $self->user( value )
#-------------------------------------------------
sub user {
    my ( $self, $p ) = @_;

    $self->{__USER__} = $p if ( defined $p );
    return( $self->{__USER__} );
        
} # end user

#-------------------------------------------------
# $self->get_auth_model_name(  )
#-------------------------------------------------
sub get_auth_model_name {
    my ( $self ) = shift;

    return $self->{__MODELS__}{__AUTH_USERS__}
            || 'Gantry::Control::Model::auth_users';
}

#-------------------------------------------------
# $self->set_auth_model_name(  )
#-------------------------------------------------
sub set_auth_model_name {
    my ( $self, $model ) = @_;

    $model = $self->get_auth_model_name() unless $model;

    $self->{__MODELS__}{__AUTH_USERS__} = $model;
}

#-------------------------------------------------
# $self->user_row( { model => '', user_name => '' } )
#-------------------------------------------------
sub user_row {
    my ( $self, @opts ) = @_;

    my $options = (@opts == 1) && UNIVERSAL::isa($opts[0], 'HASH')
            ? shift(@opts) : { @opts }; 

    $self->set_auth_model_name( $options->{model} );

    if ( defined $self->{__MODELS__}{__AUTH_USERS__} ) {
        
        # use request user_name if passed to function
        my $user_name = defined $options->{user_name} ?
            $options->{user_name} : $self->user;

        my @rows = $self->{__MODELS__}{__AUTH_USERS__}->search(
                { user_name => $user_name }, $self, undef
        );

        return( $rows[0] ) if @rows;
    }
    else {
        die( "failed to lookup user: unknown auth_users model" );
    }

    return; # don't know
    
} # end user_row

#-------------------------------------------------
# $self->user_id( { model => '', user_name => '' } )
#-------------------------------------------------
sub user_id {
    my ( $self, @opts ) = @_;

    my $row = $self->user_row( @opts );

    ( defined $row ) ? return $row->user_id : return;
}

#-------------------------------------------------
# $self->post_max( value )
#-------------------------------------------------
sub post_max {
    my ( $self, $p ) = @_;

    $self->{__POST_MAX__} = $p if ( defined $p );
    return( $self->{__POST_MAX__} );
        
} # end POST_MAX

#-------------------------------------------------
# $self->ap_req( value )
#-------------------------------------------------
sub ap_req {
    my ( $self, $p ) = @_;

    $self->{__AP_REQ__} = $p if ( defined $p );
    return( $self->{__AP_REQ__} );
        
} # end ap_req

#-------------------------------------------------
# $self->params( value )
#-------------------------------------------------
sub params {
    my ( $self, $p ) = @_;

    $self->{__PARAMS__} = $p if ( defined $p );
    return( $self->{__PARAMS__} );
        
} # end params

#-------------------------------------------------
# $self->get_param_hash()
#-------------------------------------------------
sub get_param_hash {
    my $self  = shift;
    
    my %param = ();
    
    eval {
        %param = %{ $self->params };
    };
    if ( $@ ) {
        die "$@";
    }
    
    return wantarray ? %param : \%param;

} # end get_param_hash

#-------------------------------------------------
# $self->protocol( value )
#-------------------------------------------------
sub protocol {
    my ( $self, $p ) = @_;

    $self->{__PROTOCOL__} = $p if ( defined $p );
    return( $self->{__PROTOCOL__} );
        
} # end protocol

##-------------------------------------------------
## $self->get_conf( )
##-------------------------------------------------
#sub get_conf {
#   my $class    = shift;
#    my $instance = shift;
#    my $file     = shift;
#
#    return Gantry::Conf->retrieve(
#       $instance,
#       $file
#   );
#}

#-------------------------------------------------
# $self->cleanup( $r )
# note: this function should be redefined in the application.
# This will act as the default but it's recommended
# that only global cleanup rules are defined here
# 
# application note: for "proper" or suggested practice,
# the application level cleanup function should immeadiatly
# call:
#
# $self->SUPER::cleanup( $r );
#
# After the call to SUPER, the application level cleanup 
# should include its cleanup intructions.
#-------------------------------------------------
sub cleanup {
    my ( $self ) = @_;

    # db_disconnect( $$self{dbh} );

} # end cleanup

#-------------------------------------------------
# $self->custom_error( @errors )
#-------------------------------------------------
sub custom_error {
    my( $self, @err ) = @_;
    
    eval "use Data::Dumper";

    my $die_msg         = join( "\n", @err );
    
    my $param_dump      = Dumper( $self->params );
    $param_dump =~ s/(?:^|\n)(\s+)/&trim( $1 )/ge;
    $param_dump =~ s/</&lt;/g;

    my $request_dump    = Dumper( $self );
    my $response_dump   = '';
    $request_dump =~ s/(?:^|\n)(\s+)/&trim( $1 )/ge;
    $request_dump =~ s/</&lt;/g;

    my $page = $self->_error_page();
    
    $page =~ s/##DIE_MESSAGE##/$die_msg/sg;
    $page =~ s/##PARAM_DUMP##/$param_dump/sg;
    $page =~ s/##REQUEST_DUMP##/$request_dump/sg;
    $page =~ s/##RESPONSE_DUMP##/$response_dump/sg;
    $page =~ s/##STATUS##/Forbidden/sg;
    $page =~ s/##PAGE_TITLE##/$self->page_title/sge;
    
    return( $page );
    

} # end custom_error

sub trim {
    my $spaces = $1;

    my $new_sp = " " x int( length($spaces) / 4 );
    return( "\n$new_sp" );
}

#-------------------------------------------------
# $self->_error_page()
#-------------------------------------------------
sub _error_page {
    my( $self ) = ( shift );
    
    return( qq!
    <html>
    <head>
        <title>##PAGE_TITLE## ##STATUS##</title>
        <style type="text/css">
            body {
                font-family: "Bitstream Vera Sans", "Trebuchet MS", Verdana,
                            Tahoma, Arial, helvetica, sans-serif;
                color: #ddd;
                background-color: #eee;
                margin: 0px;
                padding: 0px;
            }
            div.box {
                background-color: #ccc;
                border: 1px solid #aaa;
                padding: 4px;
                margin: 10px;
                -moz-border-radius: 10px;
            }
            div.error {
                font: 20px Tahoma;
                background-color: #88003A;
                border: 1px solid #755;
                padding: 8px;
                margin: 4px;
                margin-bottom: 10px;
                -moz-border-radius: 10px;
            }
            div.infos {
                font: 9px Tahoma;
                background-color: #779;
                border: 1px solid #575;
                padding: 8px;
                margin: 4px;
                margin-bottom: 10px;
                -moz-border-radius: 10px;
            }
            .head {
                font: 12px Tahoma;
            }
            div.name {
                font: 12px Tahoma;
                background-color: #66B;
                border: 1px solid #557;
                padding: 8px;
                margin: 4px;
                -moz-border-radius: 10px;
            }
        </style>
    </head>
    <body>
        <div class="box">
            <div class="error">##DIE_MESSAGE##</div>
            <div class="infos"><br/>
    
    <div class="head"><u>site.params</u></div>
    <br />
    <pre>
##PARAM_DUMP##
    </pre>
    
    <div class="head"><u>site</u></div><br/>
    <pre>
##REQUEST_DUMP##
    </pre>
    <div class="head"><u>Response</u></div><br/>
    <pre>
##RESPONSE_DUMP##
    </pre>
    
    </div>
    
        <div class="name">Running on Gantry $Gantry::VERSION</div>
    </div>
    </body>
    </html>! );
    
} # end _error_page

1;

__END__

=head1 NAME 

Gantry - Web application framework for mod_perl, cgi, etc.

=head1 SYNOPSIS

 use Gantry qw/-Engine=MP13 -TemplateEngine=Default/;
 use Gantry qw/-Engine=MP13 -TemplateEngine=TT/;
 use Gantry qw/-Engine=CGI  -TemplateEngine=TT/;
 use Gantry qw/-Engine=MP20/;

=head1 DESCRIPTION

Note, if you want to know how to use Gantry, you should probably start
by reading L<Gantry::Docs::QuickStart> or L<Gantry::Docs::Tutorial>.

Perl Web application framework for Apache/mod_perl. Object Oriented design 
for a pragmatic, modular approach to URL dispatching.  Supports MVC
(or VC, MC, C, take your pick) and initiates rapid development. This
project offers an orgainized coding scheme for web applications.

=head1 METHODS

=over 4

=item handler

This is the default handler that can be inherited it calls init, and
cleanup. Methods to be called from this handler should be of the naming
convention do_name. If this cannot be found then the autoloader is
called to return declined. Methods should take $r, and any other
parameters that are in the uri past the method name. 

=item init

The init is called at the begining of each request and sets values such as,
app_rootp, img_rootp, and other application set vars.

=item declined 

 $self->declined( 1 );

Set and unset the declined flag

=item relocate

 $self->relocate( location );

This method can be called from any controller will relocated 
the user to the given location

=item redirect 

 $self->redirect( 1 );

Set and unset the redirect flag

=item no_cache

 $self->no_cache( 1 );

Set and unset the no cache flag. This directive informs Apache to
either send the the no_cache header or not. 

=item template_disable 

 $self->template_disable( 1 );

Set and unset the template disable flag. 

=item method

 $self->method;
 $self->method( $r->method );

Set/get the apache request method, either 'POST' or 'GET'

=item cleanroot

 $self->cleanroot( uri, root );

Splits the URI and returns and array of the individual path
locations.

=item cleanup

 $self->cleanup

This method is called at the end of the request phase to cleanup,
disconnect for a database, etc.

=item custom_error

Generates an error page.  Feel free to override this to change the
appearance of the error page.

=item get_cookies

 $hash_ref_of_cookies = $self->get_cookies();
 $cookie_value = $self->get_cookies( 'key_of_cookie' );

If called without any parameters, this method will return a reference  
to a hash of all cookie data. Otherwise, by passing a key to this
method then the value for the requested cookie is returned.

=item set_cookie

 $self->set_cookie( { 
    name => cookie name,
    value => cookie value,
    expire => cookie expires,
    path => cookie path,
    domain => cookie domain,
    secure => [0/1] cookie secure,
  } )

This method can be called repeatedly and it will create the cookie
and push it into the response headers.

=item cookie_stash

Used by set_cookie to store/buffer cookies for the CGI engine.
Not intended for direct calls.

=item response_headers

Dual use accessor.

Parameters:
    key
    value

Returns: always returns the hash of headers

Omit the key and value for pure getter behavior.

=item r - The Apache Request 

 $r = $self->r; 
 $self->r( $r );

Set/get for apache request object

=item cgi

 $cgi = $self->cgi; $self->cgi( CGI::Simple->new() );

Set/get for CGI::Simple object. See CGI::Simple docs. This method is only
available when using the CGI engine.

=item uri 

 $uri = $self->uri; 
 $self->uri( uri );

Set/get for server uri

=item location

 $location = $self->location; 
 $self->location( location );

Set/get for server location

=item current_url

 $url_for_email = $self->current_url

Get the url of the current page.  This combines protocol, base_server and
uri to form a valid url suitable for inclusion in an email.

=item path_info

 $path_info  = $self->path_info; $self->path_info( path_info );

Set/get for server path_info

=item content_type

 $type = $self->content_type;
 $self->content_type( 'text/html' );

Set/get for reponse content-type

=item content_length

 $type = $self->content_length;
 $self->content_length( $length );

Set/get for reponse content-length

=item root

 $self->root( '/home/tkeefer/myapp/root' );
 $root = $self->root;

Set/get for the root value. This value is the application root
directory that stores the templates and other application specific
files.

=item template

 $self->template( 'some_template.tt' );

Set/get for template name for current request

The filename is relative to the $self->root value, otherwise it needs to
be the full path to template file.

=item template_default

 $self->template_default( 'some_default_template.tt' );

Set/get for a template default value. If a template has not been 
defined for the request, then the default template is called.

The filename is relative to the $self->root value, otherwise it needs to
be the full path to template file.

=item template_wrapper

 $self->template_wrapper( 'wrappers/wrapper.tt' );

Set/get for the template toolkit wrapper file. The wrapper does
exactly as it says; it wrapper the ouput from the controller before
the response is sent to the client. 

The filename is relative to the $self->root value, otherwise it needs to
be the full path to template file.

=item status

Dual accessor for the HTTP status of the page hit.

=item css_root

 $self->css_root( '/home/tkeefer/myapp/root/css' );
 $css_root = $self->css_root;

Set/get for the css_root value. This value is used to locate the css
files on disk.

=item img_root

 $self->img_root( '/home/tkeefer/myapp/root/images' );
 $img_root = $self->img_root;

Set/get for the img_root value. This value is used to locate the
application image files on disk.

=item app_rootp

 $self->app_rootp( '/myapp' );
 $app_rootp = $self->app_rootp;

Set/get for the app_rootp value. This value is used to identify the
the root URI location for the web application.

=item img_rootp

 $self->img_rootp( '/myapp' );
 $img_rootp = $self->img_rootp;

Set/get for the img_rootp value. This value is used to identify the
the root URI location for the web application images.

=item web_rootp

 $self->web_rootp( 'html' );
 $web_rootp = $self->web_rootp;

Set/get for the web_rootp value. This value is used to identify the
the root URI location for the web files.

=item css_rootp

 $self->css_rootp( '/myapp/style' );
 $css_rootp = $self->css_rootp;

Set/get for the app_rootp value. This value is used to identify the
the root URI location for the web application css files.

=item tmp_rootp

 $self->tmp_rootp( '/myapp/tmp' );
 $tmp_rootp = $self->tmp_rootp;

Set/get for the tmp_rootp value. This value is used to identify the
the root URI location for the web application temporary files.

=item editor_rootp

 $self->editor_rootp( '/fck' );
 $editor_rootp = $self->editor_rootp;

Set/get for the editor_rootp value. This value is used to identify the
the root URI location for the html editor.

=item tmp_root

 $self->tmp_rootp( '/home/httpd/html/myapp/tmp' );
 $tmp_root = $self->tmp_root;

Set/get for the tmp_root value. This value is used to identify the
the root directory location for the web application temporary files.

=item stash

Use this to store things for your template system, etc.  See Gantry::Stash.

=item smtp_host

An obscure accessor for storing smtp_host.

=item user

 $self->user( $apache_connection_user );
 $user = $self->user;

Set/get for the user value. Return the full user name of the active user.
This value only exists if the user has successfully logged in.

=item get_auth_model_name

Always returns Gantry::Control::Model::auth_users.  Override this method
if you want a different auth model.

=item set_auth_model_name

Allows you to set the auth model name, but for this to work correctly, you
must override get_auth_model_name.  Otherwise your get request will always
give the default value.

=item user_id

 $user_id = $self->user_id( model => '', user_name => '' );
 $user_id = $self->user_id;

Returns the user_id for the given user_name or for the currently logged in
user, if no user_name parameter is passed. The user_id corresponds to the 
user_name found in the auth_users table. The user_id is generally used
for changelog entries and tracking user activity within an app.

By default, the first time you call user_id or user_row during a request,
the model will be set.  It will be set to the value you pass in as model or
the value returned by calling C<<$self->get_auth_model_name>>, if no model
parameter is passed.  This module has a get_auth_model_name that always
returns 'Gantry::Control::Model::auth_users'.  If you use a different
model, override get_auth_model_name in your app's base module.  We assume
that your model has these methods: id and user_name.

=item user_row

 $user_row = $self->user_row( model => '', user_name '' );
 $user_row = $self->user_row;

The same as user_id, but it returns the whole model object (usually a
representation of a database row).

If your models are based on DBIx::Class, or any other ORM which does not
provide direct search calls on this models, you must implement a search method
in your auth_users model like this:

    sub search {
        my ( $class, $search_hash, $site_object, $extra_hash ) = @_;

        my $schema = $site_object->get_schema();

        return $schema->resultset( 'auth_users' )->search(
                $search_hash, $extra_hash
        );
    }

user_row calls this method, but DBIx::Class does not provide it for the model.
Further, the search it does provide is available through the resultset obtained
from the schema.  This module knows nothing about schema, but it passes the
self object as shown above so you can fish it out of the site object.

=item page_title

 $self->page_title( 'Gantry is for you' );
 $page_title = $self->page_title;

Set/get for the page title value. This page title is passed to the template
and used for the HTML page title. This can be set in either the Apache
LOCATION block or in the contoller. 

=item date_fmt

 $self->date_fmt( '%m %d, %Y' );
 $fmt = $self->date_fmt;

Set/get for the date format value. Used within the application for
the default date format display.

=item post_max

 $self->post_max( '4M' );
 $post_max = $self->post_max;

Set/get for the apache request post_max value. 
See Apache::Request or Apache2::Request docs.

=item ap_req

 $self->ap_req( api_call_to_apache );
 $req = $self->ap_req;

Set/get for the apache request req object. See mod_perl
documentation for intructions on how to use apache requets req.

=item get_param_hash

Always returns the params (from forms and the query string) as a hash
(not a hash reference, a real hash).

=item params

 $self->params( $self->ap_req );
 $params = $self->params;

Set/get for the request parameters. Returns a reference to a hash of
key value pairs.

=item protocol

 $self->protocol( $ENV{HTTPS} ? 'https://' : 'http://' );
 $protocol = $self->protocol;

Set/get for the request protocol. Value is either 'http://' or
'https://'. This is used to construct the full url to a resource on
the local server. 

=item get_conf

Pass this the name of the instance and (optionally) the ganty.conf
file where the conf for that instance lives.  Returns whatever
Gantry::Conf->retrieve returns.

=item make_stash

For internal use.  Makes a new stash.  The old one is lost.

=item trim

For internal use in cleaning up Data::Dumper output for presentation on
the default custom_error page.

=item schema_base_class

Not yet implemented.  Currently you must code this in your model base class.

Dual use accessor so you can keep track of the base model class name
when using DBIx::Class.

=back

=head1 MODULES

=over 4

=item Gantry::Stash

Main stash object for Gantry

=item L<Gantry::Utils::Model>

Gantry's native object relational model base class

=item L<Gantry::Utils::DBIxClass>

DBIx::Class base class for models

=item L<Gantry::Plugins::DBIxClassConn>

Mixin providing get_schema which returns DBIx::Class::Schema for
data models

=item L<Gantry::Utils::CDBI>

Class::DBI base class for models

=item L<Gantry::Plugins::CRUD>

Helper for flexible CRUD coding scheme.

=item L<Gantry::Plugins::AutoCRUD>

provides a more automated approach to
CRUD (Create, Retrieve, Update, Delete) support

=item L<Gantry::Plugins::Calendar>

These module creates a couple calendar views that can be used by other
applications and are highly customizeable. 

=item L<Gantry::Engine::MP13>

This module is the binding between the Gantry framework and the mod_perl API.
This particluar module contains the mod_perl 1.0 specific bindings.

See mod_perl documentation for a more detailed description for some of these
bindings.

=item L<Gantry::Engine::MP20>

This module is the binding between the Gantry framework and the mod_perl API.
This particluar module contains the mod_perl 2.0 specific bindings.

See mod_perl documentation for a more detailed description for some of these
bindings.

=item L<Gantry::Control>

This module is a library of useful access functions that would be used
in other handlers, it also details the other modules that belong to the
Control tree.

=item L<Gantry::Utils::DB>

These functions wrap the common DBI calls to Databases with error
checking. 

=item L<Gantry::Template::TT>

This is recommended templating system in use by by Gantry. 

=item L<Gantry::Template::Default>

This modules is used to to bypass a tempalting system and used if you
prefer to output the raw text from within the controllers.

=item L<Gantry::Utils::HTML>

Implements HTML tags in a browser non-specfic way conforming to 
3.2 and above HTML specifications.

=item L<Gantry::Utils::SQL>

This module supplies easy ways to make strings sql safe as well as 
allowing the creation of sql commands. All of these commands should 
work with any database as they do not do anything database specfic, 
well as far as I know anyways.

=item L<Gantry::Utils::Validate>

This module allows the validation of many common types of input.

=item L<Gantry::Server>

Stand alone web server used for testing Gantry applications and for 
quick delopment of Gantry applications. This server is not recommended
for production use.

=item L<Gantry::Conf>

Flexible configuration system for Gantry

=back

=head1 SEE ALSO

L<perl(3)>, L<httpd(3)>, L<mod_perl(3)>

=head1 LIMITATIONS

Limitations are listed in the modules they apply to.

=head1 JOIN US

Please visit http://www.usegantry.org for project information, 
sample applications, documentation and mailing list subscription instructions.

Web:
L<http://www.usegantry.org>

Mailing List:
L<http://www.usegantry.org/mailinglists/>

IRC:
#gantry on irc.slashnet.org

=head1 AUTHOR

Tim Keefer <tkeefer@gmail.com>

Phil Crow <philcrow2000@yahoo.com>

Gantry was branched from Krkit version 0.16 
Sat Jun 11 15:27:28 CDT 2005

=head1 COPYRIGHT and LICENSE

Copyright (c) 2005-6, Tim Keefer.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut
