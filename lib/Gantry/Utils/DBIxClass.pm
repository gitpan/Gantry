package Gantry::Utils::DBIxClass;
use strict; use warnings;

use base 'DBIx::Class';

__PACKAGE__->mk_classaccessor( 'base_model' );

use overload
    '""'        => sub { shift->stringify_self },
    fallback    => 1; # Shhh. Say nothing for other ops.

sub get_listing {
    my ( $class, $params ) = @_;

    my $order_fields = $params->{ order_by }
                 || join ', ', @{ $class->get_foreign_display_fields };

    my $attrs = { order_by => $order_fields };

    $attrs->{ rows } = $params->{ rows } if ( defined $params->{ rows } );
    $attrs->{ page } = $params->{ page } if ( defined $params->{ page } );

    return $params->{ schema }->resultset( $class->table_name )->search(
        undef, $attrs
    )
}

sub get_form_selections {
    my ( $class, $params ) = @_;

    my %retval;

    foreach my $foreign_table ( $class->get_foreign_tables() ) {
        my $short_table_name = $foreign_table->table_name;
        my $foreigners       = $foreign_table->get_foreign_display_fields();
        my $order_by         = join ', ', @{ $foreigners };

        my $value_method     = 'id';
        if ( $foreign_table->can( 'get_value_method' ) ) {
            $value_method = $foreign_table->get_value_method();
        }

        my @foreign_display_rows =
                $params->{ schema }->resultset( $short_table_name )->search(
                        undef, { order_by => $order_by }
                );

        my @items;
        push( @items, { value => '', label => '- Select -' } );

        foreach my $item ( @foreign_display_rows ) {
            push @items, {
                value => $item->$value_method,
                label => $item->foreign_display(),
            }
        }

        $retval{ $short_table_name } = \@items;
    }

    return \%retval;
}

sub stringify_self {
    my $self = shift;

    return $self->id();
}

sub create {
    my ( $class, $args ) = @_;

    my $new_row = $args->{ schema }->resultset( $class->table )->create(
            $args->{ values }
    );

    return $new_row;
}

sub gcreate {
    my $class       = shift;
    my $gantry_site = shift;

    return $gantry_site->get_schema->resultset( $class->table )->create( @_ );
}

sub gsearch {
    my $class       = shift;
    my $gantry_site = shift;

    return $gantry_site->get_schema->resultset( $class->table )->search( @_ );
}

sub gfind {
    my $class       = shift;
    my $gantry_site = shift;

    return $gantry_site->get_schema->resultset( $class->table )->find( @_ );
}

sub gfind_or_create {
    my $class       = shift;
    my $gantry_site = shift;

    return $gantry_site->get_schema->
                resultset( $class->table )->find_or_create( @_ );
}

sub gupdate_or_create {
    my $class       = shift;
    my $gantry_site = shift;

    return $gantry_site->get_schema->
                resultset( $class->table )->update_or_create( @_ );
}

sub ssearch {
    my $class  = shift;
    my $schema = shift;

    return $schema->resultset( $class->table )->search( @_ );
}

sub sfind {
    my $class  = shift;
    my $schema = shift;

    return $schema->resultset( $class->table )->find( @_ );
}

sub sfind_or_create {
    my $class  = shift;
    my $schema = shift;

    return $schema->resultset( $class->table )->find_or_create( @_ );
}

sub supdate_or_create {
    my $class  = shift;
    my $schema = shift;

    return $schema->resultset( $class->table )->update_or_create( @_ );
}

1;

=head1 NAME

Gantry::Utils::DBIxClass - a DBIx::Class subclass models can inherit from

=head1 SYNOPSIS

    package YourModel;

    use base 'Gantry::Utils::DBIxClass';

    # standard DBIx::Class table definition

    __PACKAGE__->sequence_name( 'your_seq' );
    __PACKAGE__->base_model( 'Your::Schema' );

=head1 DESCRIPTION

By inheriting from this module instead of from DBIx::Class directly, you gain
additional helper methods which various parts of Gantry use.

=head1 METHODS

=over 4

=item get_listing

Parameters: A hash reference with these keys:

    schema   - a DBIx::Class::Schema object
    order_by - [optional] a valid SQL ORDER BY clause

Returns: an array of all rows in your table.  The default order is the
foreign_display fields.

=item get_form_selections

Parameters: A hash reference with this key:

    schema - a DBIx::Class::Schema object

Returns: A hash keyed by foreign table name storing an array of items.
Each item is a hash with two keys like this:

    {
        value => $item->$value_method
        label => $item->foreign_display(),
    }

This is precisely the format that all Gantry CRUD schemes expect in their
forms.

The value_method is either id (the default) or the result of calling the
optional get_value_method on the relevant foreign table model class.

=item stringify_self

This is an overload callback used when database row objects are in
string context.  The one here calls id on the row object.  Children should
override if their primary key is not a single column called 'id'.

=item create

This method is provided for historical reasons and should no longer be used,
see gcreate below.

=back

In addition to the above methods, this base class provides the following
convenience accessors to save typing.  For example, instead of typing:

    my $schema = $self->get_schema();
    my @rows   = $schema->resultset( 'table_name' )->search(
            { ... },
            { ... }
    );

These methods let you say:

    my @rows => $TABLE_NAME->gsearch(
            $self,
            { ... },
            { ... }
    );

=over 4

=item gcreate

=item gsearch

=item gfind

=item gfind_or_create

=item gupdate_or_create

=back

For these methods to work, the invoking controller must use
Gantry::Plugins::DBIxClassConn.  It handles dbic connections and exports
get_schema which all of the g methods call.

Alternatively, if you are in a script, you may use other similar methods:

    my $schema = AddressBook::Model->connect(
        $conf->{ dbconn },
        $conf->{ dbuser },
        $conf->{ dbpass },
    );

    my @rows => $TABLE_NAME->ssearch( $schema, ... );

These methods expect a valid dbic schema as their first argument.
The available s* methods are:

=over 4

=item screate

=item ssearch

=item sfind

=item sfind_or_create

=item supdate_or_create

=back

=head1 AUTHOR

Phil Crow <philcrow2000@yahoo.com>

=head1 COPYRIGHT and LICENSE

Copyright (c) 2006, Phil Crow

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut
