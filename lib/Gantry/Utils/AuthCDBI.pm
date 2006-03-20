package Gantry::Utils::AuthCDBI;
use strict; use warnings;

use base 'Class::DBI::Sweet';

# note we ask for auth_db_Main to be imported, but it comes in as db_Main
use Gantry::Utils::ModelHelper qw(
    auth_db_Main
    get_form_selections
    retrieve_all_for_main_listing
);

my $db_options = { __PACKAGE__->_default_attributes };

__PACKAGE__->_remember_handle('Main');

sub get_db_options {
    return $db_options;
}
   
#-------------------------------------------------
# original_db_Main
#-------------------------------------------------   
# override default to avoid using Ima::DBI closure
sub original_db_Main {
    my $dbh;

    if ( defined $ENV{'AUTH_DBCONN'} ) {
        my $dbh;

        $db_options->{AutoCommit} = 0;

        # $config is my config object. replace with your own settings...
        $dbh = DBI->connect_cached(
                $ENV{'AUTH_DBCONN'},
                $ENV{'AUTH_DBUSER'},
                $ENV{'AUTH_DBPASS'},
                $db_options
        );

        return $dbh;
    }

    unless ( defined $mod_perl::VERSION ) {
        $dbh = $Gantry::Utils::CDBI::Helper::auth_dbh;

        unless ( $dbh ) {
            my $conn_info = Gantry::Utils::CDBI::Helper->auth_conn_info();
            $db_options->{AutoCommit} = 0;

            $dbh = DBI->connect_cached(
                    $conn_info->{ 'auth_dbconn' },
                    $conn_info->{ 'auth_dbuser' },
                    $conn_info->{ 'auth_dbpass' },
                    $db_options
                    );
            $Gantry::Utils::CDBI::Helper::auth_dbh = $dbh;
        }

        return $dbh;
    }

    my( $mp1, $mp2 );
    if (  $mod_perl::VERSION =~ /^1/ ) {
        $mp1 = 1;
    }
    else {
        $mp2 = 1;
    }

    my $r;
    $r = Apache->request() if $mp1;
    $r = Apache2::RequestUtil->request if $mp2;

    if ( $ENV{'MOD_PERL'} and !$Apache::ServerStarting ) {
        $dbh = $r->pnotes('auth_dbh');
    }
    if ( !$dbh ) {

    # $config is my config object. replace with your own settings...
        $dbh = DBI->connect_cached(
                $r->dir_config( 'auth_dbconn' ),
                $r->dir_config( 'auth_dbuser' ),
                $r->dir_config( 'auth_dbpass' ),
                $db_options
        );

        if ( $ENV{'MOD_PERL'} and !$Apache::ServerStarting ) {
            $r->pnotes( 'auth_dbh', $dbh );
        }
    }

    return $dbh;

} # end db_Main

#-------------------------------------------------
# db_Main
#-------------------------------------------------   
# This method supplied by Gantry::Utils::ModelHelper

#-------------------------------------------------
# $class->get_form_selctions
#-------------------------------------------------
# This method supplied by Gantry::Utils::ModelHelper

#-------------------------------------------------
# $class->retrieve_all_for_main_listing
#-------------------------------------------------
# This method supplied by Gantry::Utils::ModelHelper

1;

=head1 NAME

Gantry::Utils::AuthCDBI - Class::DBI base model for Gantry Auth

=head1 SYNOPSIS

This module expects to retrieve the database connection,
username and password from the apache conf file like this:

<Location / >
	PerlOptions +GlobalRequest
	
	PerlSetVar auth_dbconn 'dbi:Pg:[database]'
	PerlSetVar auth_dbuser 'myuser'
	PerlSetVar auth_dbpass 'mypass'
</Location>

Or, from the cgi engines constructor:

    my $cgi = Gantry::Engine::CGI->new(
        locations => ...,
        config => {
	        auth_dbconn =>  'dbi:Pg:[database]',
	        auth_dbuser =>  'myuser',
	        auth_dbpass =>  'mypass',
        }
    );

Or, from a script:

    #!/usr/bin/perl

    use Gangtry::Utils::DBConnHelper::Script;

    Gangtry::Utils::DBConnHelper::Script->set_auth_db_conn(
        {
	        auth_dbconn =>  'dbi:Pg:[database]',
	        auth_dbuser =>  'myuser',
	        auth_dbpass =>  'mypass',
        }
    );

=head1 DESCRIPTION

This module provide the base methods for Class::DBI, including the db
connection through Gantry::Utils::ModelHelper (and its friends in
the Gantry::Utils::DBConnHelper family).

=head1 AUTHOR

Tim Keefer <tkeefer@gmail.com>

=head1 COPYRIGHT and LICENSE

Copyright (c) 2005-6, Tim Keefer.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut
