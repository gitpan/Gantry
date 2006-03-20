use strict;
use Module::Build;
use File::Find;

print( '*' x 80, "\n" );
print( "Gantry Framework\n" );
print( '*' x 80, "\n" );

my $subclass = Module::Build->subclass(
    class 	=> 'My::Builder',
	code 	=> &_custom_code(),
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
	install_web_directories => 	{ 
		'prod' 	=> '/home/httpd/html/gantry',
		'dev' 	=> '/home/httpd/html/gantry',
		'tim'	=> '/home/tkeefer/httpd/html/gantry' 
	},
	create_makefile_pl => 'passthrough',
    license            => 'perl',
    module_name        => 'Gantry',
    requires           => {
        'perl'                      => '5.8',
        'Date::Calc'                => 0,
        'CGI::Simple'               => 0,
        'Template'                  => 0,
		'Data::Page'				=> 0,
        'Data::FormValidator'       => 0,
        'HTML::Prototype'			=> 0,
	    'URI'                       => 0,
		'Data::UUID'				=> 0,
        'Class::DBI'                => 0,
        'Class::DBI::Sweet'         => 0,
        'DBI'                       => 0,
        'File::Copy::Recursive'     => 0,
        'Config::General'           => 0,
        'Hash::Merge'               => 0,
    },
    build_requires      => {
        'Test::Exception'     => 0,
    },
    create_makefile_pl 	=> 'passthrough',
    script_files 		=> [ glob('bin/*') ],
    'recursive_test_files' => 1,
);

$build->create_build_script;

sub _custom_code {

	return( q{

	use File::Copy::Recursive qw( dircopy );
 
	sub ACTION_code {
		my $self = shift;
		$self->SUPER::ACTION_code();

		$self->add_build_element( 'web' );
		
		$self->process_web_files( 'web' );

	}

	sub ACTION_install {
        my $self = shift;
	 	$self->SUPER::ACTION_install();
		my $p = $self->{properties};		
		
		print "\n";
		print "-" x 80;
		print "Web Directory\n";
		print "-" x 80;
		print "\n";
		
		my $DEF_TMPL_DIR = $p->{install_web_directory};
		my $prompt;
		my $count = 0;
		my ( %dir_hash, @choices );
		
		#foreach my $dir_hash ( @{ $p->{install_web_directories} } ) {

			foreach my $k ( sort{ $a cmp $b }
				keys %{ $p->{install_web_directories} } ) {
				
				$prompt .= (
					sprintf( "%-7s: ", $k )
					. $p->{install_web_directories}{$k} . "\n" );
				
				push( @choices, $k );
			}
#		}
		
		$prompt .= "\nWeb Directory [" . join( ',', @choices ) . "]?\n";
		
		my $choice = 
			$self->prompt( "\n$prompt\n" );
		
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
				my $create = $self->prompt(  
					"\n\rDirectory doesn't exist. Create [yes]\n\r?"
				);
				exit if $create =~ /^n/i; 
			}
			
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
				$num = dircopy($blib_tmpl_dir, $tmpl_dir);
			};
			if ( $@ ) {
				print "Error coping templates:\n";
				print $@ . "\n";
			}
			else {
				print "Web content copied: $num\n";
			}
		}
		else {
			print "SKIPPING WEB CONTENT INSTALL\n";
		}
		print "-" x 80;
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
