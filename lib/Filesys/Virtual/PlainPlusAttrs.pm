# See bottom of file for license and copyright info
#
# This is an extension of Filesys::Virtual::Plain that adds support for
# FUSE-compliant xattrs, and simple locks to make it look like
# Filesys::Virtual::Foswiki. The main purpose of the module is for testing
# WebDAVContrib, though it could be used stand-alone to provide a simple
# WebDAV service.
#
package Filesys::Virtual::PlainPlusAttrs;

use strict;
use warnings;

use Filesys::Virtual::Plain;
our @ISA = ('Filesys::Virtual::Plain');

use POSIX ':errno_h';
use File::Path;
use Data::Dumper;
use Filesys::Virtual::Locks;
use Encode ();

our $VAR1;
our $VERSION  = '1.8.0';
our $METAFILE = '.Plain+Attrs';

# When constructing PlainPlusAttrs the root_path passed must be an
# absolute file path to the root of the filesystem e.g.
# Filesys::Virtual::PlainPlusAttrs->new({ root_path => '/tmp' })
# will use '/tmp' for '/' in all methods (and cwd will be relative to it)
#
# A subdirectory path under this root can optionally be created by passing
# location e.g.:
# Thus Filesys::Virtual::PlainPlusAttrs->new({
#         root_path => '/tmp', location => '/litmus'})
# will create /tmp/litmus. However '/' will still be '/tmp'.
sub new {
    my ( $class, $args ) = @_;

    die __PACKAGE__ . " requires root_path" unless $args->{root_path};
    my $root = $args->{root_path};
    unless ( -d $root || !-w $root ) {
        die "$root is not a writable directory";
    }

    # make the optional location
    if ( $args->{location} && !-d "$root/$args->{location}" ) {
        File::Path::make_path("$root/$args->{location}") || die $!;
    }

    my $this = $class->SUPER::new($args);

    # N.B. The semantics of root_path are not the same as in Foswiki.pm!
    $this->root_path($root);
    $this->{locks} = new Filesys::Virtual::Locks("$root/${METAFILE}+Locks");
    $this->{trace} = $args->{trace};
    return $this;
}

sub login {
    return 1;
}

sub list {
    my ( $this, $path ) = @_;
    return grep { !/\Q${METAFILE}\E/ } $this->SUPER::list($path);
}

sub list_details {
    my ( $this, $path ) = @_;

    my $content = join( "\n", $this->SUPER::list_details($path) );
    my $page = <<"HERE";
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>WebDAV $path</title>
  </head>
  <body>
    <pre>
$content
    </pre>
  </body>
</html>
HERE

    return Encode::decode_utf8($page);
}

# requires a 0 return on success in HTTP::WebDAV, and an error otherwise
sub close_write {
    my ( $this, $fh ) = @_;

    $fh->close();

    return 0;
}

# Filesys::Virtual::Plain::rmdir won't delete a dir unless it is empty
# We need to be able to for litmus.
sub rmdir {
    my ( $this, $file ) = @_;
    my $dir = $this->root_path() . $this->cwd() . $file;

    # The very act of removing the tree will obliterate the
    # xattr files stored under it. However we must also remove
    # any attribute file associated with the root directory.
    my $af = $this->_attrsFile($dir);
    unlink($af) if -e $af;
    return File::Path::remove_tree($dir);
}

sub delete {
    my ( $this, $file ) = @_;
    my $af = $this->_attrsFile($file);
    unlink($af) if -e $af;
    return $this->SUPER::delete($file);
}

# xattrs (properties) are stored in meta-data files associated with
# the files they carry prperties for, and must be moved/deleted at
# the same time.
sub getxattr {
    my ( $this, $path, $name ) = @_;
    my $attrs = $this->_readAttrs($path);
    $! = POSIX::EBADF unless defined $attrs->{$name};
    return $attrs->{$name};
}

# $flags may be XATTR_CREATE or XATTR_REPLACE
# XATTR_CREATE should fail if the attribute exists already
# XATTR_REPLACE should fail if he attribute does not exist already
sub setxattr {
    my ( $this, $path, $name, $val, $flags ) = @_;
    my $attrs = $this->_readAttrs($path);
    $attrs->{$name} = $val;
    return $this->_writeAttrs( $path, $attrs );
}

sub removexattr {
    my ( $this, $path, $name, $val, $flags ) = @_;
    my $attrs = $this->_readAttrs($path);
    delete $attrs->{$name};
    return $this->_writeAttrs( $path, $attrs );
}

sub listxattr {
    my ( $this, $path ) = @_;
    my $attrs = $this->_readAttrs($path);
    return ( keys %$attrs, 0 );
}

sub lock_types {
    my ( $this, $path ) = @_;
    return 3;    # exclusive and shared (advisory) locks supported
}

sub add_lock {
    my ( $this, %lockstat ) = @_;
    $lockstat{taken} ||= time();
    $this->{locks}->addLock( taken => time(), %lockstat );
}

sub refresh_lock {
    my ( $this, $locktoken ) = @_;
    Carp::confess unless $locktoken;
    my $lock = $this->{locks}->getLock($locktoken);
    $lock->{taken} = time();
}

# Boolean true if it succeeded
sub remove_lock {
    my ( $this, $locktoken ) = @_;
    Carp::confess unless $locktoken;
    return $this->{locks}->removeLock($locktoken);
}

# Get the locks active on the given path
# $recurse can be 0 (only this node) 1 (this node and immediate children)
# or -1 (infinite) to inspect those resources.
sub get_locks {
    my ( $this, $path, $recurse ) = @_;
    my @locks = $this->{locks}->getLocks( $path, $recurse );

    # reap timed-out locks on this resource
    my $i = scalar(@locks) - 1;
    while ( $i >= 0 ) {
        my $lock = $locks[$i];
        Carp::confess unless $lock->{token};
        if (   $lock->{timeout} >= 0
            && $lock->{taken} + $lock->{timeout} < time() )
        {
            $this->{locks}->removeLock( $lock->{token} );
            splice( @locks, $i, 1 );
        }
        else {
            $i--;
        }
    }
    return @locks;
}

sub _readAttrs {
    my ( $this, $path ) = @_;
    my $f = $this->_attrsFile($path);
    my $F;
    if ( open( $F, "<", $f ) ) {
        local $/;
        eval { <$F> };
        close($F);
        return $VAR1;
    }
    return {};
}

sub _writeAttrs {
    my ( $this, $path, $attrs ) = @_;
    my $f = $this->_attrsFile($path);
    if ( scalar( keys %$attrs ) ) {
        my $F;
        open( $F, ">", $f ) || return $!;
        print $F Data::Dumper->Dump( [$attrs] );
        return 0 if close($F);
    }
    elsif ( -e $f ) {
        return 0 if unlink($f);
    }
    return -1;
}

sub _attrsFile {
    my ( $this, $path ) = @_;
    my $f = $this->root_path() . $this->cwd() . $path;
    return $f if $path =~ /\Q${METAFILE}\E(_\d+)?$/;
    if ( -d $f ) {
        return "$f/${METAFILE}";
    }
    elsif ( $f =~ m#(.*)\/(.*?)$# ) {
        return "$1/${METAFILE}_$2";
    }
    else {
        die "Bad path $f";
    }
}

1;

__END__

Copyright (C) 2009-2012 WikiRing http://wikiring.com
Copyright (C) 2012-2024 Foswiki Contributors 

This program is licensed to you under the terms of the GNU General
Public License, version 2. It is distributed in the hope that it will
be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

This software cost a lot in blood, sweat and tears to develop, and
you are respectfully requested not to distribute it without purchasing
support from the authors (available from webdav@c-dot.co.uk). By working
with us you not only gain direct access to the support of some of the
most experienced Foswiki developers working on the project, but you are
also helping to make the further development of open-source Foswiki
possible. 

Author: Crawford Currie http://c-dot.co.uk
