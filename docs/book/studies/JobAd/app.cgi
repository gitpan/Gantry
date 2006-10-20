#!/usr/bin/perl
use strict;


use CGI::Carp qw( fatalsToBrowser );

use JobAd qw{ -Engine=CGI -TemplateEngine=TT };

use Gantry::Engine::CGI;

my $cgi = Gantry::Engine::CGI->new( {
    config => {
        dbconn => 'dbi:SQLite:dbname=app.db',
        template_wrapper => 'genwrapper.tt',
        root => 'html',
    },
    locations => {
        '/' => 'JobAd',
        '/job' => 'JobAd::Job',
        '/skill' => 'JobAd::Skill',
        '/position' => 'JobAd::Position',
        '/auth_users' => 'JobAd::AuthUsers',
        '/auth_groups' => 'JobAd::AuthGroups',
        '/auth_group_members' => 'JobAd::AuthGroupMembers',
        '/auth_pages' => 'JobAd::AuthPages',
    },
} );

$cgi->dispatch();

if ( $cgi->{config}{debug} ) {
    foreach ( sort { $a cmp $b } keys %ENV ) {
        print "$_ $ENV{$_}<br />\n";
    }
}
