package Filesys::Virtual::Attachments;

use strict;
use warnings;

use Filesys::Virtual::Foswiki ();
our @ISA = ('Filesys::Virtual::Foswiki');

#use Data::Dump qw(dump);

sub new {
    my $class = shift;
    my $args  = shift;

    my $this = bless( $class->SUPER::new($args), $class );

    $Filesys::Virtual::Foswiki::FILES_EXT = '';
    @Filesys::Virtual::Foswiki::views     = ();

    return $this;
}

sub _parseResource {
    my ( $this, $resource ) = @_;

    if ( defined $this->{location} && $resource =~ s/^$this->{location}// ) {

        # Absolute path; must be, cos it has a location
    }
    elsif ( $resource !~ /^\// ) {

        # relative path
        $resource = $this->{path} . '/' . $resource;
    }
    $resource =~ s/\/\/+/\//g;    # normalise // -> /
    $resource =~ s/^\/+//;        # remove leading /

    # Resolve the path into it's components
    my @path;
    foreach ( split( /\//, $resource ) ) {
        if ( $_ eq '..' ) {
            if ($#path) {
                pop(@path);
            }
        }
        elsif ( $_ eq '.' ) {
            next;
        }
        elsif ( $_ eq '~' ) {
            @path = ( $Foswiki::cfg{UsersWebName} );
        }
        else {
            push( @path, $_ );
        }
    }

    # strip off hidden attribute from filename
    @path = map { $_ =~ s/^\.//; $_ } @path if $this->{hideEmptyAttachmentDirs};

    # rebuild normalized resource
    $resource = join( "/", @path );

    # descend through webs
    my $web = '';
    while ( scalar(@path) ) {
        last if $web && Foswiki::Func::topicExists( $web, $path[0] );
        $web .= ( $web ? '/' : '' ) . shift(@path);
    }

    my %info = (
        type       => 'R',
        web        => $web,
        resource   => $resource,
        topic      => shift(@path),
        attachment => shift(@path),
    );

    # anything else is an error
    return undef if scalar(@path);

    # derive type from found resources and rebuild path
    @path = ();
    if ( $info{web} ) {
        push @path, $info{web};

        if ( $info{topic} ) {
            push @path, $info{topic};

            if ( $info{attachment} ) {
                $info{type} = 'A';
                push @path, $info{attachment};
            }
            else {
                $info{type} = 'D';
            }
        }
        else {
            $info{type} = 'W';
        }
    }

    $info{path} = join( "/", @path );

    #print STDERR dump(\%info)."\n";

    return \%info;
}

1;

