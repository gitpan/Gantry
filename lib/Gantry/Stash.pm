package stash;

use strict;

use Gantry::Stash::View;
use Gantry::Stash::Controller;

#-------------------------------------------------
# AUTOLOAD
#-------------------------------------------------
sub AUTOLOAD {
    my $self    = shift;
    my $command = our $AUTOLOAD;
    $command    =~ s/.*://;

    die( "Undefined stash method: $command" );

} # end AUTOLOAD

#-------------------------------------------------
# DESTROY
#-------------------------------------------------
sub DESTROY { }

#-------------------------------------------------
# new
#-------------------------------------------------
sub new {
    my $class = shift;
    my $self  = bless( {}, $class );
    return $self;

} # end new

#-------------------------------------------------
# view
#-------------------------------------------------
sub view {
    my $self = shift;

    $self->{__VIEW__} = view->new() unless defined $self->{__VIEW__};

    return $self->{__VIEW__};

} # end view

#-------------------------------------------------
# controller
#-------------------------------------------------
sub controller {
    my $self = shift;

    $self->{__CONTROLLER__} = controller->new() 
		unless defined $self->{__CONTROLLER__};

    return $self->{__CONTROLLER__};

} # end controller

1;

__END__

=head1 NAME

Gantry::Stash - Main stash object for Gantry

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FUNCTIONS

=over 4

=head1 METHODS

=over 4

=item view

	Returns the 'view' stash object

=item controller

	Returns the 'controller' stash object

=head1 MODULES

=over 4

=item Gantry::Stash::View

=item Gantry::Stash::Controller

=back

=head1 SEE ALSO

Gantry(3), Gantry::Stash(3)

=head1 LIMITATIONS

=head1 AUTHOR

Phil Crow <pcrow@sunflowerbroadband.com>
Tim Keefer <tkeefer@gmail.com>

=head1 COPYRIGHT and LICENSE

Copyright (c) 2005, Phil Crow.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut

