package Gantry::Template::TT;
require Exporter;

use Template;
use vars qw( @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS );

############################################################
# Variables                                                #
############################################################
@ISA 		= qw( Exporter );
@EXPORT 	= qw( 
	do_action
	do_error
	do_process 
	template_engine
);

@EXPORT_OK 	= qw( );

my %tt;

############################################################
# Functions                                                #
############################################################
#-------------------------------------------------
# $self->do_action( 'do_main|do_edit', @p )
#-------------------------------------------------
sub do_action {
	my( $self, $action, @p ) = @_;
	
	# stash the output from the action ie. do_main, do_edit
	# for use when do_process is call.
	$self->stash->controller->data( $self->$action( @p ) ); 

} # end do_action

#-------------------------------------------------
# $self->do_error( @err )
#-------------------------------------------------
sub do_error {
	my( $self, @err ) = @_;
	
	#$self->r->log_error( join( "\n", @err ) ); 

} # end do_error

#-------------------------------------------------
# $site->do_process(  )
#-------------------------------------------------
sub do_process {
	my( $self ) = @_;
	
	# Check template disabled flag
	if ( $self->template_disable ) {
		return( $self->stash->controller->data );
	}
	
	# Process through template tookit
	else {
        if ( not defined $tt{ $self->location } ) {
		    $tt{ $self->location } = Template->new({
		    	WRAPPER 		=> $self->template_wrapper,
		    	INCLUDE_PATH 	=> $self->root, 		
		    	DEFAULT			=> $self->template_default,
		    });
        }
		
		# Use the template defined in controller use template from PerlSetVar
		if ( ! defined  $self->stash->view->template ) {
			$self->stash->view->template( $self->template );
		}
		
		my $page;
		$tt{ $self->location }->process( $self->stash->view->template, 
			{ self => $self, site => $self, view => $self->stash->view }, 
			\$page 
		) || die( "Template Error: " . $tt{ $self->location }->error );	
		
		return( $page );
	}
} # end do_process

#-------------------------------------------------
# $site->template_engine
#-------------------------------------------------
sub template_engine {
	return __PACKAGE__;
	
} # end template_engine
# EOF
1;

__END__

=head1 NAME 

Gantry::Template::TT - Template Toolkit plugin for Gantry.

=head1 SYNOPSIS

  use Gantry::Template::TT;


=head1 DESCRIPTION

This is plugin module that contains the Template Toolkit method calls.  

=head1 METHODS

=over 4

=item $site->do_action

C<do_action> is a required function for the template plugin. It purpose
is to call or dispatch to the appropriate method. This function is passed 
three parameters: 

my( $self, $action, @path_array ) = @_;

This method is responsible for calling the controller method and 
storing the output from the controller.

=item $site->do_error

This method gives you the flexibility of logging, re-estabilishing a
database connection, rebuilding the template object, etc.

=item $site->do_process

This method is the final step in the template plugin. Here you need
call the template object passing the controller data and return the 
output. 

See Gantry::Template::TT

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
