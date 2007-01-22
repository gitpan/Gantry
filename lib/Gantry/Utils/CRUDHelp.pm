package Gantry::Utils::CRUDHelp;
use strict;

use base 'Exporter';

our @EXPORT = qw(
    clean_dates
    form_profile
    clean_params
    write_file
);

sub write_file {
    my( $self, $field, $archive ) = @_;
    
    my $upload = $self->file_upload( $field );

    my $id = $upload->{unique_key};
    $upload->{ident} = $id  . $upload->{suffix}; 
    
    my $file = File::Spec->catfile( $archive, $upload->{ident} );

    open( FH, ">$file" ) or die "Error $!";
    binmode FH;

    my( $buffer, $buffer_size ) = ( '', 14096 );
    while ( read( $upload->{filehandle}, $buffer, $buffer_size ) ) {
        print FH $buffer;
    }        
    close FH;
    
    return( {
        "$field"            => $file,
        "${field}_ident"    => $upload->{ident},
        "${field}_suffix"   => $upload->{suffix},
        "${field}_mime"     => $upload->{mime},
        "${field}_name"     => $upload->{name},
        "${field}_size"     => $upload->{size},      
     } );

}

# If a field is a date and its value is false, make it undef.
sub clean_dates {
    my ( $params, $fields ) = @_;

    foreach my $field ( @{ $fields } ) {
        my $name = $field->{name};

        if ( ( $field->{is} eq 'date' )
                and
             ( not $params->{ $name } )
           )
        {
            $params->{ $name } = undef;
        }
    }
}

# build the profile that Data::FormValidator wants
sub form_profile {
    my ( $form_fields ) = @_;
    my @required;
    my @optional;
    my %constraints;

    foreach my $item ( @{ $form_fields } ) {
        if ( defined $$item{optional} and $$item{optional} ) {
            push @optional, $$item{name};
        }
        else {
            push @required, $$item{name};
        }

        if ( defined $$item{constraint} and $$item{constraint} ) {
            $constraints{ $$item{name} } = $$item{constraint};
        }
    }

    my %retval;

    $retval{required}           = \@required    if @required;
    $retval{optional}           = \@optional    if @optional;
    $retval{constraint_methods} = \%constraints if ( keys %constraints );

    return \%retval;
}

# If a field's type is not boolean, and its value is false, make that
# value undef.
sub clean_params {
    my ( $params, $fields ) = @_;

    foreach my $p ( keys %{ $params } ) {
        delete( $params->{$p} ) if $p =~ /^\./;
    }
    
    FIELD:
    foreach my $field ( @{ $fields } ) {
        my $name = $field->{name};

        next FIELD unless ( defined $field->{ is } );
        next FIELD unless ( defined $field->{ name } );
        next FIELD unless ( defined $params->{ $name } );

        if ( $field->{ is } =~ /^varchar/i and $params->{ $name } eq '' ) {
            $params->{ $name } = undef;
        }
        elsif ( $field->{ is } =~ /^int/i and $params->{ $name } eq '' ) {
            $params->{ $name } = undef;
        }
        elsif ( ( $field->{is} !~ /^bool/i and $field->{is} !~ /^int/i )
                and
             ( not $params->{ $name } )
           )
        {
            $params->{ $name } = undef;
        }
    }
}

1;

__END__

=head1 NAME 

Gantry::Utils::CRUDHelp - helper routines for CRUD plugins

=head1 SYNOPSIS

    use Gantry::Utils::CRUDHelp;

=head1 DESCRIPTION

Exports helper functions useful when writing CRUD plugins.

=head1 FUNCTIONS

=over 4

=item clean_params

Pass a hash of form parameters and the fields list from a
C<Gantry::Plugins::AutoCRUD > style form method.  Any field with
key is whose value is not boolean is examined in the params hash.  If its
value is false, that value is changed to undef.  This keeps the ORM
from trying to insert a blank string into a date and integer fields which
is fatal, at least for DBIx::Class inserting into Postgres.

=item clean_dates

Pass a hash of form parameters and the fields list from a
C<Gantry::Plugins::AutoCRUD > style form method.  Any field with
key is whose value is date is examined in the params hash.  If its
value is false, that value is changed to undef.  This keeps the ORM
from trying to insert a blank string into a date field which is fatal,
at least for Class::DBI inserting into Postgres.

=item form_profile

Pass in the fields list from a C<Gantry::Plugins::AutoCRUD > style _form
method.  Returns a hash reference suitable for passing to the
check method of Data::FormValidator.

=back

=head2 write_file( <form field name>, <file archive> );

write_file provides the code to collect a file from the form and write it to 
disk. This is to be called in the edit_post_action or add_post_action callback.

=head3 usage

 sub edit_post_action {
    my( $self, $row ) = @_;
    
    my %params = $self->get_param_hash;
        
    if ( defined %params{'myfile'} ) {
    
        my $u = $self->write_file( 'myfile', '/home/html/images' );
        $row->update( $u );
    }   
 }
 

=head3 recommend database fields

 <file field>   varchar  -- /path to file>/11677952634.59186549016706.jpg
 <file field>_ident  varchar -- 11677952634.59186549016706.jpg ( unique )
 <file field>_suffix varchar -- .txt
 <file field>_mime   varchar -- text/html
 <file field>_name   varchar -- originalfilename.txt
 <file field>_size   int     -- 2323

=head3 returns

will produce a hash ref
 
 {
    '<file field>'  => '/home/archive/11677952634.59186549016706.jpg',
    '<file field>_ident'  => '11677952634.59186549016706.jpg',
    '<file field>_suffix' => '.txt',
    '<file field>_mime'   => 'text/html',
    '<file field>_name'   => 'originalfilename.txt',
    '<file field>_size'   => '2323',
 }

=head1 SEE ALSO

 Gantry::Plugins::AutoCRUD (for simpler situations)
 Gantry::Plugins::CRUD (for slightly more complex situations)

=head1 AUTHOR

Phil Crow <philcrow2000@yahoo.com>

=head1 COPYRIGHT

Copyright (c) 2005, Phil Crow.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut
