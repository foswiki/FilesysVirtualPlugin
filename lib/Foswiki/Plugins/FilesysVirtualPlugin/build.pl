#!/usr/bin/perl -w
package Foswiki::Plugins::FilesysVirtualPlugin::Build;

BEGIN {
    unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} );
}

use base 'Foswiki::Contrib::Build';

sub new {
    my $class = shift;
    my $this  = $class->SUPER::new('FilesysVirtualPlugin');

}

# Override manifest filter to handle lib/Filesys/Virtual/Foswiki.pm
sub _twikify_manifest {
    my ( $this, $from, $to ) = @_;

    $this->SUPER::_twikify_manifest( $from, $to );

    $this->_filter_file(
        $to, $to,
        sub {
            my ( $this, $text ) = @_;
            $text =~ s#^(lib/.*)/Foswiki.pm(.*)$#$1/TWiki.pm$2#gm;
            return $text;
        }
    );
}

sub target_twiki {
    my $this = shift;

    $this->SUPER::target_twiki();

    # create Filesys::Virtual::TWiki.pm
    my $of = 'lib/Filesys/Virtual/Foswiki.pm';
    my $nf = 'lib/Filesys/Virtual/TWiki.pm';
    foreach my $filter (@Foswiki::Contrib::Build::twikiFilters) {
        if ( $of =~ /$filter->{RE}/ ) {
            my $fn = $filter->{filter};
            $this->$fn( $this->{basedir} . '/' . $of,
                $this->{basedir} . '/' . $nf );
            $this->_filter_file(
                $this->{basedir} . '/' . $nf,
                $this->{basedir} . '/' . $nf,
                sub {
                    my ( $this, $text ) = @_;
                    $text =~ s/::Foswiki/::TWiki/g;
                    return $text;
                }
            );
            print "Created $nf\n";
            last;
        }
    }
}

my $build = new Foswiki::Plugins::FilesysVirtualPlugin::Build;

# Build the target on the command line, or the default target
$build->build( $build->{target} );

1;
