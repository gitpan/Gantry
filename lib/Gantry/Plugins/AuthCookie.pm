package Gantry::Plugins::AuthCookie;
use strict; use warnings;

use Gantry;
use Gantry::Utils::HTML qw( :all );

use Crypt::CBC;
use MIME::Base64;
use Digest::MD5 qw( md5_hex );
use Authen::Htpasswd;
use Authen::Htpasswd::User;

# lets export a do method and some conf accessors
use base 'Exporter';
our @EXPORT = qw( 
    do_login 
    auth_user_row 
    auth_user_groups 
    auth_require
    auth_groups
    auth_deny
    auth_optional
    auth_table
    auth_file
    auth_secret
    auth_user_field
    auth_password_field
    auth_logout_url
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
        { phase => 'init',      callback => \&initialize },
        { phase => 'post_init', callback => \&auth_check },
    );
}

#-----------------------------------------------------------
# initialize
#-----------------------------------------------------------
sub initialize {
    my( $gobj ) = @_;

    # set a test cookie to check later
    $gobj->set_cookie( {  
        name     => 'acceptcookies', 
        value    => 'acceptcookies', 
        path     => '/',
    } ); 

    $gobj->auth_optional( $gobj->fish_config( 'auth_optional' ) || 'no' );
    $gobj->auth_deny( $gobj->fish_config( 'auth_deny' ) || 'no' );
    $gobj->auth_table( $gobj->fish_config( 'auth_table' ) || 'user' );
    $gobj->auth_file( $gobj->fish_config( 'auth_file' ) || '' );
    
    $gobj->auth_user_field( 
        $gobj->fish_config( 'auth_user_field' ) || 'ident'
    );
    
    $gobj->auth_password_field(
        $gobj->fish_config( 'auth_password_field' ) || 'password'
    );
    
    $gobj->auth_require( 
        $gobj->fish_config( 'auth_require' ) || 'valid-user'
    );
    
    $gobj->auth_groups( $gobj->fish_config( 'auth_groups' ) || '' );
    $gobj->auth_secret( $gobj->fish_config( 'auth_secret' ) || 'w3s3cR7' );
        
    # initialize these in the Gantry object
    $gobj->auth_user_row( {} );
    $gobj->auth_user_groups( {} );
    
}

#-----------------------------------------------------------
# auth_check
#-----------------------------------------------------------
sub auth_check {
    my $gobj = shift;

    if ( $gobj->auth_optional() eq 'yes' ) {
        validate_user( $gobj );
    }
    elsif ( $gobj->auth_deny() eq 'yes' ) {

        # check auth && redirect if not authed
        if ( ! validate_user( $gobj ) ) {
            
            # set to to the login page
            my $uri = $gobj->uri;
            $uri    =~ s!/!:!g;                
            $gobj->relocate( $gobj->app_rootp . "/login/$uri" );
        }

    }
}

#-----------------------------------------------------------
# validate_user
#-----------------------------------------------------------
sub validate_user {
    my $gobj = shift;

    # immediately return success for login and static
    my $app_rootp = $gobj->app_rootp() || '';
    my $regex     = qr/^${app_rootp}\/(login|static).*/;
    
    return 1 if $gobj->uri =~ /^$regex/;

    my $cookie    = $gobj->get_cookies( 'auth_cookie' );
    return 0 if ! $cookie;
        
	my( $username, $password ) = decrypt_cookie( $gobj, $cookie );

	return 0 if ( ! $username || ! $password );

    my $user_groups = {};

    if ( $gobj->auth_file() ) {
        my $pwfile = Authen::Htpasswd->new(
            $gobj->auth_file(), { encrypt_hash => 'md5' }
        );
        
        my $user = $pwfile->lookup_user( $username );
        return 0 if ! $user;
        
        if ( $user->check_password( $password ) ) {
            
            my $pwfile = Authen::Htpasswd->new(
                $gobj->auth_file(), { encrypt_hash => 'md5' }
            );

            my $user = $pwfile->lookup_user( $username );

            if ( $user && $user->check_password( $password ) ) {
                my $hash = {
                    user_id => $username,
                    password => $password,
                };
                my $obj = bless(
                     $hash, 'Gantry::Plugins::AuthCookie::HtpasswdRow' 
                );
                
                $gobj->auth_user_row( $obj );
            }
            else {
                return 0;             
            }
            
        }
        else {
            return 0;
        }
    }
    # look up via DBIC
    else {
        my $sch       = $gobj->get_schema();
        my @user_rows = $sch->resultset( $gobj->auth_table() )->search( { 
            $gobj->auth_user_field()   => $username,
            $gobj->auth_password_field() => $password,
        } );
	
    	return 0 unless @user_rows;

        # put the user row into the gantry object
        $gobj->auth_user_row( $user_rows[0] );

        my $dbh = $sch->storage->dbh;

        my( @sql, $group_ident );
        
        push( @sql,
            'select g.ident from user u, user_groups m, user_group g',
            'where m.user = u.id and m.user_group = g.id',
            'and u.id = ', $user_rows[0]->id
        );
        
        my $q = $dbh->prepare( join( ' ', @sql ) );
        $q->execute();
        $q->bind_columns( \$group_ident );

        foreach ( $q->fetchrow_arrayref ) {
            ++$user_groups->{ $group_ident };
        }  
        
    }

    # put the user groups into the gantry object
    $gobj->auth_user_groups( $user_groups );	

    if ( $gobj->auth_require() eq 'group' ) {
        my @groups = split( /\s*,\s*/, $gobj->auth_groups() );

        # loop over groups and return 1 if user group exists
        foreach ( @groups ) {
            return 1 if defined $user_groups->{$_};
        }
        
        # otherwise return 0
        return 0;
    }
    
    # return success
    return 1;
    
} # end validate_user

#-----------------------------------------------------------
# do_login
#-----------------------------------------------------------
sub do_login {
 	my ( $self, $page ) = @_;

	my %param = $self->get_param_hash();

    if ( defined $param{logout} ) {

    	$self->set_cookie( {  
                name     => 'auth_cookie',
                value    => '', 
                expires  => 0, 
                path     => '/',
        } );  

        my $relocation;

        eval {
            $relocation = $self->auth_logout_url;
        };
        if ( $@ ) {
            $relocation = auth_logout_url( $self );
        }

        $self->relocate( $relocation );
        return();    
    }
    
    $page ||= $param{page};
    
    $self->stash->view->template( 'login.tt' );
    $self->stash->view->title( 'Login' );

    # set a test cookie to check later
    $self->set_cookie( {  
        name     => 'acceptcookies', 
        value    => 'acceptcookies', 
        path     => '/',
    } ); 
    
    my @errors;
	if ( ! ( @errors = checkvals( $self )  ) ) {

		my $encd = encrypt_cookie( 
		    $self, 
		    $param{username}, 
		    $param{password} 
		);

		# set cookie, redirect to do_frontpage.
        $self->set_cookie( {  
            name     => 'auth_cookie', 
            value    => $encd, 
            path     => '/',
        } ); 

        if ( $page ) {
            $page =~ s/\:/\//g;
            $self->relocate( $page );
        }
        else {
            $self->relocate( $self->app_rootp . '/' );
        }
        
        return();
	}

    my $retval = {};

    $retval->{page}       = $page;
    $retval->{param}      = \%param;
    $retval->{login_form} = login_form( $self, $page );
    $retval->{errors}     = ( $self->is_post() ) ? \@errors : 0;
    
    $self->status( $self->status_const( 'FORBIDDEN' ) );
    $self->stash->view->data( $retval );
   
}

#-------------------------------------------------
# login_form( $self )
#-------------------------------------------------
sub login_form {
	my ( $self, $page ) = @_;
    
    my %in    = $self->get_param_hash();
    $in{page} = $page;
    
    my @form = ( ht_form( $self->uri ),
			q!<TABLE border=0>!,
                ht_input( 'page', 'hidden', \%in ),
			q!<TR><TD><B>Username</B><BR>!,
			ht_input( 'username', 'text', \%in, 'size=15 id="username"' ),
			qq!</TD></TR>!,

			q!<TR><TD><B>Password</B><BR>!,
			ht_input( 'password', 'password', \%in, 'size=15' ),
			q!</TD></TR>!,

			q!<TR><TD align=right>!,
			ht_submit( 'submit', 'Log In' ),
			q!</TD></TR>!,

			q!</TABLE>!,
			ht_uform() 
    );

    return( join( ' ', @form ) );
} # END login_form

#-------------------------------------------------
# decrypt_cookie
#-------------------------------------------------
sub decrypt_cookie {
	my ( $self, $encrypted ) = @_;
	
	$^W = 0; # Crappy perl module dosen't run without warnings.

	my $c = new Crypt::CBC ( {	
        'key' 		=> $self->auth_secret(),
        'iv'        => '$KJh#(}q',
        'cipher' 	=> 'Blowfish',
        'padding'	=> 'null',
        'header'    => 'none',
    } );

	my $p_text = $c->decrypt( MIME::Base64::decode( $encrypted ) );
	
	$c->finish();

	my ( $user, $pass, $md5 ) = split( ':;:', $p_text );

	my $omd5 = md5_hex( $user . $pass );

#	$^W = 1;	

	if ( $omd5 eq $md5 ) {
		return( $user, $pass );
	}
	else {
		return( $user, undef );
	}

} # END decrypt_cookie

#-------------------------------------------------
# encrypt_cookie
#-------------------------------------------------
sub encrypt_cookie {
	my ( $self, $username, $pass ) = @_;

	$^W = 0;	

	$username 	||= '';
	$pass 		||= '';

	my $c = new Crypt::CBC( {	
        'key' 		=> $self->auth_secret(),
        'iv'        => '$KJh#(}q',
        'cipher' 	=> 'Blowfish',
        'header'    => 'none',
        'padding'	=> 'null' } );

	my $md5 = md5_hex( $username . $pass );
	
	my $encd 	= $c->encrypt("$username:;:$pass:;:$md5");
	my $c_text 	= MIME::Base64::encode( $encd, '');

	$c->finish();

	$^W = 1;	

	return( $c_text );
    
} # END encrypt_cookie

#-------------------------------------------------
# login_checkvals( $in )
#-------------------------------------------------
sub checkvals {
	my ( $self ) = @_;

    my %in = $self->get_param_hash();
    
	my @errors;

	if ( ! $in{username} ) {
		push( @errors, 'Enter your username' );
	}
	
	if ( ! $in{password} ) {
		push( @errors, 'Enter your password' );
	}

	#if ( $self->get_cookies( 'acceptcookies' ) ) {
	#	push( @errors, '<B>You must have cookies enabled.</B>' );
	#}

    if ( ! @errors ) {
        if ( $self->auth_file() ) {
             my $pwfile = Authen::Htpasswd->new(
                $self->auth_file(), { encrypt_hash => 'md5' }
            );

            my $user = $pwfile->lookup_user( $in{username} );

            if ( $user && $user->check_password( $in{password} ) ) {
                my $hash = {
                    user_id => $in{username},
                    password => $in{password},
                };
                my $obj = bless(
                     $hash, 'Gantry::Plugins::AuthCookie::HtpasswdRow' 
                );
                
                $self->auth_user_row( $obj );
            }
            else {
                push( @errors, 'Invalid user' );                
            }            
        }
        else {
            eval {
                my $sch = $self->get_schema();
                my @rows = $sch->resultset( $self->auth_table() )->search( {
                    $self->auth_user_field()  => $in{username},
                    $self->auth_password_field()  => $in{password},
                } );

                if ( @rows ) {
                    $self->auth_user_row( $rows[0] );
                }
                else {
                    push( @errors, 'Invalid user' );
                }
            };
            if ( $@ ) {
                die 'Error: (perhaps you didn\'t include AuthCookie in '
                    . "the same list as -Engine?).  Full error: $@";
            }
        }
    }
    
	return( @errors );
} # END login_checkvals

#-------------------------------------------------
# $self->auth_optional
#-------------------------------------------------
sub auth_optional {
    my ( $self, $p ) = ( shift, shift );

    $$self{__AUTH_OPTIONAL__} = $p if defined $p;
    return( $$self{__AUTH_OPTIONAL__} ); 
    
} # end auth_optional

#-------------------------------------------------
# $self->auth_deny
#-------------------------------------------------
sub auth_deny {
    my ( $self, $p ) = ( shift, shift );

    $$self{__AUTH_DENY__} = $p if defined $p;
    return( $$self{__AUTH_DENY__} ); 
    
} # end auth_deny

#-------------------------------------------------
# $self->auth_table
#-------------------------------------------------
sub auth_table {
    my ( $self, $p ) = ( shift, shift );

    $$self{__AUTH_TABLE__} = $p if defined $p;
    return( $$self{__AUTH_TABLE__} ); 
    
} # end auth_table

#-------------------------------------------------
# $self->auth_user_field
#-------------------------------------------------
sub auth_user_field {
    my ( $self, $p ) = ( shift, shift );

    $$self{__AUTH_USER_FIELD__} = $p if defined $p;
    return( $$self{__AUTH_USER_FIELD__} ); 
    
} # end auth_user_field

#-------------------------------------------------
# $self->auth_password_field
#-------------------------------------------------
sub auth_password_field {
    my ( $self, $p ) = ( shift, shift );

    $$self{__AUTH_PASSWORD_FIELD__} = $p if defined $p;
    return( $$self{__AUTH_PASSWORD_FIELD__} ); 
    
} # end auth_password_field

#-------------------------------------------------
# $self->auth_secret
#-------------------------------------------------
sub auth_secret {
    my ( $self, $p ) = ( shift, shift );

    $$self{__AUTH_SECRET__} = $p if defined $p;
    return( $$self{__AUTH_SECRET__} ); 
    
} # end auth_secret

#-------------------------------------------------
# $self->auth_require
#-------------------------------------------------
sub auth_require {
    my ( $self, $p ) = ( shift, shift );

    $$self{__AUTH_REQUIRE__} = $p if defined $p;
    return( $$self{__AUTH_REQUIRE__} ); 
    
} # end auth_require

#-------------------------------------------------
# $self->auth_file
#-------------------------------------------------
sub auth_file {
    my ( $self, $p ) = ( shift, shift );

    $$self{__AUTH_FILE__} = $p if defined $p;
    return( $$self{__AUTH_FILE__} ); 
    
} # end auth_file

#-------------------------------------------------
# $self->auth_groups
#-------------------------------------------------
sub auth_groups {
    my ( $self, $p ) = ( shift, shift );

    $$self{__AUTH_GROUPS__} = $p if defined $p;
    return( $$self{__AUTH_GROUPS__} ); 
    
} # end auth_groups

#-------------------------------------------------
# $self->auth_user_row
#-------------------------------------------------
sub auth_user_row {
    my ( $self, $p ) = ( shift, shift );

    $$self{__AUTH_USER_ROW__} = $p if defined $p;
    return( $$self{__AUTH_USER_ROW__} ); 
    
} # end auth_user_row

#-------------------------------------------------
# $self->auth_user_groups
#-------------------------------------------------
sub auth_user_groups {
    my ( $self, $p ) = ( shift, shift );

    $$self{__AUTH_USER_GROUPS__} = $p if defined $p;
    return( $$self{__AUTH_USER_GROUPS__} ); 
    
} # end auth_user_groups

#-------------------------------------------------
# $self->auth_logout_url
#-------------------------------------------------
sub auth_logout_url {
    my ( $self, $p ) = ( shift, shift );

    $$self{__AUTH_LOGOUT_URL__} = $p if defined $p;
    return( $$self{__AUTH_LOGOUT_URL__} || $self->app_rootp . '/login' ); 
    
} # end auth_logout_url

package Gantry::Plugins::AuthCookie::HtpasswdRow;

sub id {
    my $self = shift;
    return $self->{user_id};
}

sub username {
    my $self = shift;
    return $self->{user_id};
}

sub password {
    my $self = shift;
    return $self->{password};
}

sub ident {
    my $self = shift;
    return $self->{user_id};
}


1;

__END__

=head1 NAME

Gantry::Plugins::AuthCookie - Plugin for cookie based authentication

=head1 SYNOPSIS

In Apache Perl startup or app.cgi or app.server:

    <Perl>
        # ...
        use MyApp qw{ -Engine=CGI -TemplateEngine=TT AuthCookie };
    </Perl>
    
Inside MyApp.pm:

    use Gantry::Plugins::AuthCookie;

    sub namespace {
        return 'wantauthcookie'; # the string is up to you
    }

=head1 DESCRIPTION

This plugin mixes in a method that will supply the login routines and 
accessors that will store the authed user row and user groups.

Note that you must include AuthCookie in the list of imported items
when you use your base app module (the one whose location is app_rootp).
Failure to do so will cause errors.

You also need a namespace method in the base module.  The namespace
is up to you, but don't pick 'Gantry'.  The namespace will be used
to register callbacks for this plugin.  If you don't set a namespace,
all apps in the apache instance with your app will have to use the
AuthCookie plugin, or they will die horrible deaths for lack of accessors,
while they are being needlessly subjected to auth.

=head1 CONFIGURATION

Authentication can be turned on and off by setting 'auth_deny'. If 'on',
then validation is turned on and the particular location will require that the 
user is authed. After the successful login the user row and the user groups 
( if any ) will be set into the Gantry site object and can be retrieved using
the $self->auth_user_row and $self->auth_user_groups accessors. 
 
 auth_deny           'no' / 'yes'              # default 'off'
 auth_table          'user_table'              # default 'user'
 auth_file           '/path/to/htpasswd_file'  # Apache htpasswd file
 auth_user_field     'ident'                   # default 'ident'
 auth_password_field 'password'                # default 'password'
 auth_require        'valid-user' or 'group'   # default 'valid-user'
 auth_groups         'group1,group2'           # allow these groups
 auth_secret         'encryption_key'          # default 'w3s3cR7'
 
=head1 METHODS

=over 4

=item do_login

this method provides the login form and login routines.

=item auth_user_row

This is mixed into the gantry object and can be called retrieve the DBIC user
row.

=item auth_user_groups

This is mixed into the gantry object and can be called to retrieve the
defined groups for the authed user.

=item get_callbacks

For use by Gantry.pm.  Registers the callbacks needed to auth pages
during PerlHandler Apache phase or its moral equivalent.

=back

=head1 CONFIGURATION ACCESSORS

=over 4

=item auth_deny

accessor for auth_deny. Turns authentication on when set to 'on'.

=item auth_optional

accessor for auth_optional. User validation is active when set to 'on'.

=item auth_table

accessor for auth_table. Tells AuthCookie the name of the user table. 
default is 'user'. 

=item auth_file

accessor for auth_file. Tells AuthCookie to use the Apache style htpasswd file
and where the file is located.

=item auth_user_field

accessor for auth_user_field. Tells AuthCookie the name of the username field
in the user database table.

=item auth_password_field

accessor for auth_password_field. Tells AuthCookie the name of the password
field in the user database table.

=item auth_require

accessor for auth_require. Tells AuthCookie the type of requirement for the
set authentication. It's either 'valid-user' (default) or 'group'

=item auth_groups

accessor for auth_groups. This tells AuthCookie which groups are allowed 
which is enforced only when auth_require is set to 'group'. You can supply
multiple groups by separating them with commas.

=item auth_secret

accessor for auth_secret. auth_secret is the encryption string used to 
encrypt the cookie. You can supply your own encryption string or just use the
default the default value.

=item auth_logout_url

accessor for auth_logout_url.  auth_logout_url is a full URL where the
user will go when they log out.  Logging out happens when the do_login
method is called with a query_string parameter logout=1.

=back

=head1 PRIVATE SUBROUTINES

=over 4

=item auth_check

callback for auth check.

=item checkvals

check for login form.

=item decrypt_cookie

decryption routine for cookie.

=item encrypt_cookie

encryption routine for cookie.

=item initialize

callback to initialize plugin configuration.

=item login_form

html login form.

=item validate_user

validation routines.

=back

=head1 SEE ALSO

    Gantry

=head1 AUTHOR

Timotheus Keefer <tkeefer@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 Timotheus Keefer

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut