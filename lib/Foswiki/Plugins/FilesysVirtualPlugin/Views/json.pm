# See bottom of file for license and copyright information
package Foswiki::Plugins::FilesysVirtualPlugin::Views::json;

use strict;
use warnings;

use IO::String                                   ();
use JSON                                         ();
use Foswiki::Func                                ();
use Foswiki::Plugins::FilesysVirtualPlugin::View ();

our @ISA = qw( Foswiki::Plugins::FilesysVirtualPlugin::View );

sub new {
    my $class = shift;

    my $this = $class->SUPER::new(@_);
    $this->extension(".json");

    return $this;
}

sub DESTROY {
    my $this;

    undef $this->{_json};
}

sub json {
    my $this = shift;

    $this->{_json} = JSON->new->utf8->pretty() unless $this->{_json};

    return $this->{_json};
}

sub read {
    my ( $this, $web, $topic ) = @_;

    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );

    # Trim back the meta to a useable form
    my %data;
    foreach my $k ( keys %$meta ) {
        if ( $k !~ /^_/ || $k eq '_text' ) {
            $data{$k} = $meta->{$k};
        }
    }
    unless ( defined $data{_text} ) {
        $data{_text} = $text;
    }

    return IO::String->new( $this->json->encode( \%data ) );
}

sub write {
    my ( $this, $web, $topic, $json ) = @_;

    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );

    my $data = $this->json->decode($json);
    foreach my $k ( keys %$data ) {
        if ( $k !~ /^_/ || $k eq '_text' ) {
            $meta->{$k} = $data->{$k};
        }
    }
    $text = $data->{_text} if defined $data->{_text};

    return $this->saveTopic( $web, $topic, $meta, $text );
}

1;

__END__

Copyright (C) 2010-2012 Crawford Currie http://c-dot.co.uk
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
