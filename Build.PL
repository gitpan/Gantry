use strict;
use Module::Build;
use File::Find;

print( '*' x 80, "\n" );
print( "Gantry Framework\n" );
print( '*' x 80, "\n" );

my $subclass = Module::Build->subclass(
    class   => 'My::Builder',
    code    => &_custom_code(),
);

# collect web files
my( %web_dirs, @web_dirs );

find( \&wanted, 'root' );

sub wanted {

    my $dir = $File::Find::dir;
    $dir =~ s![^/]*/!!;

    next if $dir =~ /\.svn/;

    ++$web_dirs{ $dir };
}

push( @web_dirs, '/*.*' );
foreach my $k ( sort { $a cmp $b } keys %web_dirs ) {
    print "[web dir] $k\n";
    push( @web_dirs, ( $k . '/*.*' ) );
}
    
my $build = $subclass->new(
    web_files => \@web_dirs,
    build_web_directory => 'root',
    install_web_directories =>  { 
        'default' => '/home/httpd/html/gantry',
        'prod'    => '/home/httpd/html/gantry',
        'dev'     => '/home/httpd/html/gantry',
        'tim'     => '/home/tkeefer/httpd/html/gantry' 
    },
    create_makefile_pl => 'passthrough',
    license            => 'perl',
    module_name        => 'Gantry',
    requires           => {
        'perl'                      => '5.8',
        'CGI::Simple'               => 0,
        'Template'                  => '2.0',
        'URI'                       => 0,
        'Data::UUID'                => 0,
        'DBI'                       => 0,
        'File::Copy::Recursive'     => 0,
        'HTTP::Server::Simple::CGI' => 0,
    },
    build_requires      => {
        'Test::More'          => 0,
        'Test::Exception'     => 0,
    },
    create_makefile_pl  => 'passthrough',
    script_files        => [ glob('bin/*') ],
    test_files          => [
        't/*.t',
        't/engine/*.t',
        't/plugins/*.t',
        't/utils/*.t',
        't/auth/*.t',
        't/conf/*.t',
        't/form/*.t',
        't/template/*.t',
    ],
#    'recursive_test_files' => 1,
);

$build->create_build_script;

sub _custom_code {

    return( q{

    sub ACTION_code {
        my $self = shift;
        $self->SUPER::ACTION_code();

        $self->add_build_element( 'web' );
        
        $self->process_web_files( 'web' );

    }

    sub ACTION_install {
        my $self = shift;
        
        my $p = $self->{properties};        
        
        my $initf = "$p->{install_sets}{site}{lib}/$p->{dist_name}/Init.pm";
        if ( -e $initf ) {
            require "$initf";
            $p->{install_web_directories}{default} = Gantry::Init::base_root();
        }
                
        $self->SUPER::ACTION_install();
        
        my $DEF_TMPL_DIR = $p->{install_web_directory};
        my $prompt;
        my $count = 0;
        my ( %dir_hash, @choices );

        my $choice = $self->prompt(
    ( "\n\nGantry comes with a set of default templates that\n"
    . "need to be written to disk. A typical location for these\n"
    . "templates is your web server document root.\n\n"
    . "Press enter to use the default directory or specify another directory.\n" ),
            $p->{install_web_directories}{default},
        );
        
        my $tmpl_dir;
        if ( $choice =~ /\// ) {
            $tmpl_dir = $choice;
        }
        elsif ( ! defined $p->{install_web_directories}{$choice} ) {
            $tmpl_dir = '__skip__';
        }
        else {
            $tmpl_dir = $p->{install_web_directories}{$choice}
        }
        
        $tmpl_dir =~ s/\/$//g;
            
        if( $tmpl_dir && $tmpl_dir ne '__skip__' ) {
            
            if ( ! -d $tmpl_dir ) {
                my $create = $self->y_n(  
                    "Directory doesn't exist. Create $tmpl_dir?",
                    'y'
                );
                exit unless $create =~ /^y/i; 
            }
            
            # write Init.pm file with install options
            
            open( INIT_FILE, "> blib/lib/Gantry/Init.pm" ) or die "$!";
            print INIT_FILE qq`package Gantry::Init;\n`;
            print INIT_FILE qq`use strict;\n\n`;
            print INIT_FILE qq`sub base_root {\n`;
            print INIT_FILE qq`    return "$tmpl_dir";\n`;
            print INIT_FILE qq`}\n`;
            print INIT_FILE qq`1;`;
            close INIT_FILE;

            open( INIT_FILE, "> $initf" ) or die "$!";
            print INIT_FILE qq`package Gantry::Init;\n`;
            print INIT_FILE qq`use strict;\n\n`;
            print INIT_FILE qq`sub base_root {\n`;
            print INIT_FILE qq`    return "$tmpl_dir";\n`;
            print INIT_FILE qq`}\n`;
            print INIT_FILE qq`1;`;
            close INIT_FILE;
            
            eval {  
                File::Path::mkpath( $tmpl_dir );
            };
            if ( $@ ) {
                print "Error: unable to create directory $tmpl_dir\n";
                $@ =~ s/ at .+?$//;
                die( "$@\n" );
            }
            
            my $blib_tmpl_dir = File::Spec->catdir(
                $self->blib, 'web', $p->{build_web_directory} 
            );  
            
            my $num;
            eval {
                require File::Copy::Recursive;
                import File::Copy::Recursive 'dircopy';

                $num = dircopy($blib_tmpl_dir, $tmpl_dir);
            };
            if ( $@ ) {
                print "\nError coping templates:\n";
                print $@ . "\n";
            }
            else {
                print "\n$num Gantry templates copied to $tmpl_dir\n";
            }
        }
        else {
            print "SKIPPING WEB CONTENT INSTALL\n";
        }
        
        print "\n";

    } # end ACTION_install

    sub process_web_files {
        my $self = shift;
        my $files = $self->find_web_files;
        return unless @$files;
        
        my $tmpl_dir = File::Spec->catdir($self->blib, 'web');
        File::Path::mkpath( $tmpl_dir );
        
        foreach my $file (@$files) {
            my $result = $self->copy_if_modified($file, $tmpl_dir) 
                or next;
            #$self->fix_shebang_line($result);
        }
    }

    sub find_web_files {
        my $self = shift;
        my $p = $self->{properties};
        my $b_tmpl_dir = $p->{build_web_directory};
        $b_tmpl_dir =~ s/\/$//g;

        if (my $files = $p->{web_files}) {
            if (  UNIVERSAL::isa($files, 'HASH') ) {
                my @files = [keys %$files];
                return( \@files );
            }
            
            my @files;
            foreach my $glob ( @$files ) {
                $glob = "$b_tmpl_dir/$glob";
                push( @files, glob( $glob ) );
            }       
            return( \@files );
            return( [ map $self->localize_file_path($_), @files ] );
            return( \@localized );
        } 
    }

    sub web_files {
        my $self = shift;
        for ($self->{properties}{web_files}) {
            $_ = shift if @_;
            return unless $_;
            
            # Always coerce into a hash
            return $_ if UNIVERSAL::isa($_, 'HASH');
            return $_ = {$_ => 1} unless ref();
            return { map {$_,1} @$_ };
        }
    }
    
    } ); # end return

} # end _custom_code
