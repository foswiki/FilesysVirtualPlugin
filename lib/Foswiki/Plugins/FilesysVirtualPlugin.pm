# See bottom of file for license and copyright info
package Foswiki::Plugins::FilesysVirtualPlugin;

use strict;
use warnings;

our $VERSION = '3.01';
our $RELEASE = '%$RELEASE%';
our $SHORTDESCRIPTION =
  'Implementation of the Filesys::Virtual::Plain API over a Foswiki store';
our $LICENSECODE       = '%$LICENSECODE%';
our $NO_PREFS_IN_TOPIC = 1;

sub initPlugin {
    return 1;
}

=pod

The following implementation is required if we decide to use cached permissions

use Foswiki::Plugins::FilesysVirtualPlugin::Permissions ();

my $pluginName = 'FilesysVirtualPlugin';

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    my $pdb = $Foswiki::cfg{Plugins}{FilesysVirtualPlugin}{PermissionsDB};

    if ($pdb) {
        eval 'use Foswiki::Plugins::FilesysVirtualPlugin::Permissions';
        if ( $@ ) {
            Foswiki::Func::writeWarning( $@ );
            print STDERR $@; # print to webserver log file
        } else {
            $permDB =
              new Foswiki::Plugins::FilesysVirtualPlugin::Permissions( $pdb );
        }
    } else {
        my $mess =
          "{Plugins}{FilesysVirtualPlugin}{PermissionsDB} is not defined";

        Foswiki::Func::writeWarning($mess);
        print STDERR "$mess\n";
        return 0;
    }

    unless( $permDB ) {
        my $mess = "$pluginName: failed to initialise";
        Foswiki::Func::writeWarning( $mess );
        print STDERR "$mess\n";
        return 0;
    }

    return 1;
}

sub beforeSaveHandler {
    my ( $text, $topic, $web ) = @_;

    return unless( $permDB );

    eval {
        $permDB->processText( $web, $topic, $text );
    };

    if ( $@ ) {
        Foswiki::Func::writeWarning( "$pluginName: $@" );
        print STDERR "$pluginName: $@\n";
    }
}

=cut

1;
__END__

Copyright (C) 2008 KontextWork.de
Copyright (C) 2011 WikiRing http://wikiring.com
Copyright (C) 2008-2012 Crawford Currie http://c-dot.co.uk
Copyright (C) 2011-2024 Foswiki Contributors

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

