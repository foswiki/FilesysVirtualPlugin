# See bottom of file for license and copyright information
package Foswiki::Plugins::FilesysVirtualPlugin::Views::txt;

use strict;
use IO::String    ();
use Foswiki::Func ();

our $VERSION = '1.6.1';
our $RELEASE = '%$TRACKINGCODE%';

sub extension { '.txt' }

sub read {
    my ( $this, $web, $topic ) = @_;

    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
    return IO::String->new($text);
}

sub write {
    my ( $this, $web, $topic, $text ) = @_;

    my ( $meta, $dummy ) = Foswiki::Func::readTopic( $web, $topic );
    eval { Foswiki::Func::saveTopic( $web, $topic, $meta, $text ); };
    return $@;
}

1;

__END__

Copyright (C) 2010-2012 WikiRing http://wikiring.com
Copyright (C) 2012-2020 Foswiki Contributors 

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

