# See bottom of file for license and copyright information
package Foswiki::Plugins::FilesysVirtualPlugin::View;

use strict;
use warnings;

sub new {
    my $class = shift;

    my $this = bless( {@_}, $class );

    return $this;
}

sub extension {
    my ( $this, $ext ) = @_;

    $this->{_extension} = $ext if defined $ext;

    return $this->{_extension};
}

sub read {

    # my ( $this, $web, $topic ) = @_;

    die "not implemented";
}

sub write {

    #my ( $this, $web, $topic, $text ) = @_;

    die "not implemented";
}

sub saveTopic {
    my ( $this, $web, $topic, $meta, $text ) = @_;

    eval { Foswiki::Func::saveTopic( $web, $topic, $meta, $text ); };

    return $@;
}

1;

__END__

Copyright (C) 2022 Foswiki Contributors 

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
