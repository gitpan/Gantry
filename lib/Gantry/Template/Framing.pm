package Gantry::Template::Framing;
require Exporter;

############# THIS MODULE IS NOT WORKING #########################

use Carp;
use vars qw( @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS );

############################################################
# Variables                                                #
############################################################
@ISA        = qw( Exporter );
@EXPORT     = qw( 
    do_action
    do_error
    do_process 
);

@EXPORT_OK  = qw( );

############################################################
# Functions                                                #
############################################################
#-------------------------------------------------
# $site->do_action( $r, 'do_main|do_edit', @p )
#-------------------------------------------------
sub do_action {
    my( $site, $r, $action, @p ) = @_;
    
    $site->{stash}{output} = $site->$action( $r, @p ); 

}

#-------------------------------------------------
# $site->do_error( $r, @err )
#-------------------------------------------------
sub do_error {
    my( $site, $r, @err ) = @_;
    
    $r->log_error( @err ); 

}

#-------------------------------------------------
# $site->do_process( $r, @err )
#-------------------------------------------------
sub do_process {
    my( $site ) = @_;

    my $r = $site->r();

    my $framing = webapp_get_framing( $r, $$site{frame} );      
    
    $r->print( $site->{stash}{output} );    

} 

#-------------------------------------------------
# webapp_get_framing
#-------------------------------------------------
# This module returns an instance of a framing
# for us. 
#-------------------------------------------------
sub webapp_get_framing ($;$) { 
    my ($r, $framing ) = @_;
    my $frame; 

    $framing = '' if ( ! defined $framing );

    croak "invalid apache request object: $!" if ( $r eq '' );

    # Get our framing if we don't have it
    if( ($framing eq '') || ($framing eq 'auto') ) { 
        $framing = $r->dir_config('Framing');

        croak "no framing defined: $!" if( $framing eq '' );
    }

    if (!$framing or ($framing =~ /^(off|none)$/i)) {
        $framing = 'TheWorld::Framing';
    }

    $framing = 'TheWorld::Framing::Plain' if( $framing =~ /^plain$/i );

    my ( $mod, @opt ) = split(';', $framing );

    $mod = 'TheWorld::Framing::FromTemplate' if ( $mod =~ /template/ );

    # Get an instance of our framing and put it into $frame
    eval { $frame = new $mod };

    croak "could not load framing '$mod': $!\n" if( $@ );

    croak "could not load framing '$mod': $!\n" if( ! $frame );

    $frame->set_options(@opt);

    return( $frame );
} # END webapp_get_framing
# EOF
1;

__END__

=head1 NAME

Gantry::Template::Framing - Framing  plugin for Gantry.

=head1 SYNOPSIS

  use Gantry::Template::Framing;


=head1 DESCRIPTION

To use Old World framing do something like this:

    use Gantry qw/ -Engine=YourChoice -TemplateEngine=Framing /;

This plugin module contains the method calls for the Template Framing.

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

=item webapp_get_framing

A function for internal use.  Returns to other methods of this class
an old world framing object.

=back

=head1 SEE ALSO

Gantry(3), Gantry::Template::TT


=head1 LIMITATIONS


=head1 AUTHOR

Tim Keefer <tkeefer@gmail.com>

=head1 COPYRIGHT and LICENSE

Copyright (c) 2005-6, Tim Keefer.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut
