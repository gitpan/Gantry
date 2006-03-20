package Gantry::Utils::PODViewer;

use strict;
use Gantry qw/-TemplateEngine=TT/;

our @ISA = ( 'Gantry' );

use Gantry::Utils::HTML; 
use Pod::POM::View::HTML;
use Pod::POM;
use File::Find;

#-------------------------------------------------
# $self->init( $self );
#-------------------------------------------------
sub init {
	my( $self ) = @_;
	
	$self->SUPER::init( ); 
	
	$self->{__POD_DIR__} = $self->fish_config( 'pod_dir' );

} # end init

#-------------------------------------------------
# $self->do_main( $file);
#-------------------------------------------------
sub do_main {
	my( $self, $file ) = @_;
	
	my %p = $self->get_param_hash;
	$file ||= $p{file};
	
	$self->stash->view->template( 'pod.tt' );
	$self->stash->view->title( $file );
	
	my @path = split( /\//, $self->{__POD_DIR__} );
	my $base_module = $path[-1];

	my $p = Pod::POM->new();
	
	$file = '' if $file eq $base_module;
	$file =~ s/::/\//g;
	$file = '/' . $file if $file;

	my $pom = $p->parse_file(
	 ( $self->{__POD_DIR__} . "${file}.pm" ) 
	) or die "$!";
	
	my $location = $self->location;
	
	my $d = My::View->print($pom);
	$d =~ s/<\/?body.*?>//ig;
	$d =~ s/<\/?html>//ig;
	$d =~ s/(${base_module}::)((\w+)?(::\w+)*)/<a href="$location\/main\/$2">$1$2<\/a>/g;
	$d =~ s/(${base_module}\(3\))/<a href="$location\/main\/$base_module">$1<\/a>/g;
	$d =~ s/<h1>(\w+)\s*<\/h1>/<h1><a style="text-decoration: none" name="$1">$1<\/a><\/h1>/g;

	my @headings;
	foreach my $sec ( $pom->head1() ) {
		my $stitle = $sec->title;
		$stitle =~ s/\s+/&nbsp;/g;	
		push( @headings, 
			( "<a href=\"#" . $sec->title . "\">$stitle</a> " ) );
	}
	
	my @pm_files = _collect_pm_files( $self->{__POD_DIR__} );
		
	$self->stash->view->data( {
		base_module => $base_module,
		files 		=> \@pm_files,
		headings 	=> \@headings,
		html 		=>  $d
		}
	);

} # end do_main

#-------------------------------------------------
# $self->collect_pm_files( $dir );
#-------------------------------------------------
sub _collect_pm_files {
	my( $dir ) = @_;
	
	my @files;
	
	find({ 
		wanted => sub { 
			my $file = $File::Find::name;
			$file =~ s/$dir//;
			push( @files, $file ) if $_ =~ /\.pm$/; 
		}, 
		follow => 1 
		}, 
		$dir 
	);
	
	return( sort( @files ) );
}

#-------------------------------------------------
# PACKAGE My::View
#-------------------------------------------------   
package My::View;
use base qw( Pod::POM::View::HTML );

#-------------------------------------------------
# view_head1
#-------------------------------------------------   
sub view_head1 {
	my ($self, $item) = @_;
	
	return(
		 '<a name="', $item->title->present($self), '"></a>',
		'<h1>',
		$item->title->present($self),
		"</h1>\n",
		$item->content->present($self)
	);
}

#-------------------------------------------------
# view_head2
#-------------------------------------------------   
sub view_head2 {
	my ($self, $item) = @_;
	
	return(
		 '<a name="', $item->title->present($self), '"></a>',
		'<h2>',
		$item->title->present($self),
		"</h2>\n",
		$item->content->present($self)
	);
}

1;

=head1 NAME

Gantry::Utils::PODViewer - PODViewer application

=head1 SYNOPSIS

This module is a POD viewing application. The module expects only the path
to an installed Perl module.

=head2 In mod_perl

If the deployment method is mod_perl:

    <Location /pod >
	    PerlSetVar root   				'/home/gantry/templates'
     	PerlSetVar template_wrapper 	'pod_wrapper.tt'
	    PerlSetVar pod_dir 				'/home/perl/lib/Gantry'
	    
	    SetHandler perl-script
	    PerlHandler Gantry::Utils::PODViewer
    </Location>


=head2 In CGI

On the other hand, if the deployment method is CGI:

#!/usr/local/bin/perl
use strict;

use CGI::Carp qw(fatalsToBrowser);
use Gantry::Utils::PODViewer qw( -Engine=CGI -TemplateEngine=TT );
use Gantry::Engine::CGI;

my $cgi = Gantry::Engine::CGI->new( {
  locations => {
    '/'        => 'Gantry::Utils::PODViewer',
  },
  config => {
     pod_dir        => '/home/gantry/perl/lib/lib/Gantry',
     app_rootp      => '/cgi-bin/gantry.cgi',
     root           => '/home/gantry/templates',
     template_wrapper => 'pod_wrapper.tt',
  }
} );

$cgi->dispatch;

=head1 METHODS

=over 4

=item do_main

=back


=head1 AUTHOR

Tim Keefer <tkeefer@gmail.com>

=head1 COPYRIGHT and LICENSE

Copyright (c) 2005-6, Tim Keefer.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut



