package Gantry::Control::C::Authen;
use strict;

use Gantry::Control::Model::auth_users;

######################################################################
# Main Execution Begins Here                                         #
######################################################################
sub handler : method {
	my ( $self, $r ) = @_;

	# Check Exclude paths
	if ( $r->dir_config( 'exclude_path' ) ) {
		foreach my $p ( split( /\s*;\s*/, $r->dir_config( 'exclude_path' ) )) {
			if ( $r->path_info =~ /^$p$/ ) {
				return( $self->status_const( 'OK' ) );
			}
		}
	}
	
	my ( $ret, $sent_pw ) = $r->get_basic_auth_pw;

	return( $self->status_const( 'DECLINED' ) ) 
		if ( $ret != $self->status_const( 'OK' ) );

	my $user = $r->user;
	
	unless ( defined $user && $user ) {
		$r->note_basic_auth_failure;
		$r->log_error(' [login failure: ', $self->remote_ip( $r ), ']',
			" user $user ($sent_pw) not found ", $r->uri );
			
		return( $self->status_const( 'HTTP_UNAUTHORIZED' ) );
	}

	# get user row for the user_id
	my @user_row = Gantry::Control::Model::auth_users->search( 
		user_name => $user,
		active	  => 't',
	); 
		
	unless ( @user_row ) {
		$r->note_basic_auth_failure;
		return( $self->status_const( 'HTTP_UNAUTHORIZED' ) );
	}
	
	# Do error here.
	unless ( defined $user_row[0]->crypt && $user_row[0]->crypt ) {
		$r->note_basic_auth_failure;
		$r->log_error(' [login failure: ', $self->remote_ip( $r ), ']',
			" user $user ($sent_pw) passwd not defined ", $r->uri );
		
		return( $self->status_const( 'HTTP_UNAUTHORIZED' ) );
	}

	# Do a error here as well.
	unless ( crypt( $sent_pw, $user_row[0]->crypt ) 
							eq $user_row[0]->crypt ) {

		$r->note_basic_auth_failure;
		$r->log_error(' [login failure: ', $self->remote_ip( $r ), ']',
			" user $user ($sent_pw)  passwd mismatch ", $r->uri );

		return( $self->status_const( 'HTTP_UNAUTHORIZED' ) );
	}

	return( $self->status_const( 'OK' ) );

} # END $self->handler

#-------------------------------------------------
# $self->import(  @options )
#-------------------------------------------------
sub import {
    my ( $self, @options ) = @_;
	
	my( $engine, $tplugin );
	
	foreach (@options) {
		
		# Import the proper engine
        if (/^-Engine=(.*)$/) { 
			$engine = "Gantry::Engine::$1";
			eval "use $engine"; 
			if ( $@ ) {
				die "unable to load engine $1 ($@)";
			}	
		}
		
    }
	
} # end: import

# EOF
1;

__END__

=head1 NAME 

Gantry::Control::C::Authen - Database based authentication

=head1 SYNOPSIS 

use Gantry::Control::C::Authen qw/-Engine=MP20/;

=head1 DESCRIPTION

This module allows authentication against a database.

=head1 APACHE

Sample Apache conf configuration

  <Location /location/to/auth >
    AuthType    Basic
    AuthName    "Manual"
	
	PerlSetVar  auth_dbconn		'dbi:Pg:<database_name>'
	PerlSetVar  auth_dbuser		'<database_user>'
	PerlSetVar  auth_dbpass		'<database_password>'
	
    PerlSetVar  auth_dbcommit	off

    PerlAuthenHandler 	Gantry::Control::C::Authen

    require     valid-user
  </Location>

=head1 DATABASE 

This is the table that will be queried for the authentication of the
user. 

  create table "auth_users" (
    "id"            int4 default nextval('auth_users_seq') NOT NULL,
    "user_id"		int4,
	"active"        bool,
    "user_name"     varchar,
    "passwd"        varchar,
	"crypt"			varchar,
    "first_name"    varchar,
    "last_name"     varchar,
    "email"         varchar
  );

=head1 METHODS

=over 4

=item handler

The mod_perl authen handler.

=back

=head1 SEE ALSO

Gantry::Control::C::Authz(3), Gantry::Control(3), Gantry(3)

=head1 LIMITATIONS

This and all authentication and autorization modules pre-suppose that
the auth_* tables are in the same database as the application tables.

=head1 AUTHOR

Tim Keefer <tkeefer@gmail.com>

=head1 COPYRIGHT

Copyright (c) 2005-6, Tim Keefer.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut
