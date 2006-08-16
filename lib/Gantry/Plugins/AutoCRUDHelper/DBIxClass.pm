package Gantry::Plugins::AutoCRUDHelper::DBIxClass;
use strict;

sub insert {
    my $class       = shift;
    my $gantry_site = shift;
    my $params      = shift;
    my $schema      = $gantry_site->get_schema();
    my $table_name  = $gantry_site->get_model_name->table_name();

    return $schema->resultset( $table_name )->create( $params );
}

sub retrieve {
    my $class       = shift;
    my $gantry_site = shift;
    my $id          = shift;

    my $schema      = $gantry_site->get_schema();
    my $table_name  = $gantry_site->get_model_name->table_name();

    my $retrow      = $schema->resultset( $table_name )->find( $id );

    return $retrow;
}

sub update {
    my $class       = shift;
    my $gantry_site = shift;
    my $row         = shift;
    my $params      = shift;

    $row->update( $params );
    $row->discard_changes();
}

sub delete {
    my $class       = shift;
    my $gantry_site = shift;
    my $row         = shift;

    $row->delete;
}

1;

=head1 NAME

Gantry::Plugins::AutoCRUDHelper::DBIxClass - the actual CRUD for DBIx::Class AutoCRUD

=head1 SYNOPSIS

This module is required for you by Gantry::Plugins::AutoCRUD, when your
controller's get_orm_helper module returns
'Gantry::Plugins::AutoCRUDHelper::DBIxClass'.  It supports models which
inherit from DBIx::Class.

=head1 DESCRIPTION

Inside Gantry::Plugins::AutoCRUD, whenever actual database work needs to be
done, your model is asked to supply a helper by calling get_orm_helper.
If your models use DBIx::Class, you need to implement that method and have
it return 'Gantry::Plugins::AutoCRUDHelper::DBIxClass'.

=head1 METHODS

The methods of this module are documented in Gantry::Plugins::AutoCRUD,
but here is a list to keep POD testers happy:

=over 4

=item insert

=item retrieve

=item update

=item delete

=back

=head1 SEE ALSO

    Gantry::Plugins::AutoCRUDHelper
    Gantry::Plugins::AutoCRUDHelper::CDBI

=head1 AUTHOR

Phil Crow <philcrow2000@yahoo.com>

=head1 COPYRIGHT and LICENSE

Copyright (c) 2006, Phil Crow

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut
