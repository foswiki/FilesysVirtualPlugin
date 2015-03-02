package LockTests;

use base qw(Unit::TestCase);

use strict;

use Filesys::Virtual::Locks;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub set_up {
    my $this = shift;
    $this->{db} = "./testlockdb";
}

sub tear_down {
    my $this = shift;
    unlink( $this->{db} );
}

sub test_addLock {
    my $this  = shift;
    my $locks = new Filesys::Virtual::Locks( $this->{db} );
    $locks->addLock( token => "blah", path => 'a/b/c', exclusive => 1 );
    my @l = $locks->getLocks('a/b/c');
    $this->assert_equals( 1, scalar(@l) );
    $this->assert_str_equals( "blah", $l[0]->{token} );
    @l = $locks->getLocks('a');
    $this->assert_equals( 0, scalar(@l) );
    @l = $locks->getLocks('a/b');
    $this->assert_equals( 0, scalar(@l) );
    @l = $locks->getLocks('a/b/d');
    $this->assert_equals( 0, scalar(@l) );
    $locks = undef;
    $locks = new Filesys::Virtual::Locks( $this->{db} );
    $this->assert_equals( 1, scalar( $locks->getLocks( 'a/b/c', 1 ) ) );
}

sub test_removeLock {
    my $this  = shift;
    my $locks = new Filesys::Virtual::Locks( $this->{db} );
    $locks->addLock( token => "blah", path => 'a/b/c', exclusive => 1 );
    $locks->removeLock("blah");
    $this->assert_equals( 0, scalar( $locks->getLocks('a/b/c') ) );
}

sub test_getDeepLocks {
    my $this  = shift;
    my $locks = new Filesys::Virtual::Locks( $this->{db} );
    $locks->addLock( token => "blah", path => 'a/b', depth => -1 );
    my @l = $locks->getLocks('a');
    $this->assert_equals( 0, scalar(@l) );
    @l = $locks->getLocks('a/b');
    $this->assert_equals( 1, scalar(@l) );
    $this->assert_str_equals( "blah", $l[0]->{token} );
    @l = $locks->getLocks('a/b/c');
    $this->assert_equals( 1, scalar(@l) );
    $this->assert_str_equals( "blah", $l[0]->{token} );
}

sub test_multiLocks {
    my $this  = shift;
    my $locks = new Filesys::Virtual::Locks( $this->{db} );
    $locks->addLock( token => "blah", path => 'a/b',   depth => -1 );
    $locks->addLock( token => "clah", path => 'a/b/c', depth => 0 );
    $locks = new Filesys::Virtual::Locks( $this->{db} );
    my @l = $locks->getLocks('a/b/c');
    $this->assert_equals( 2, scalar(@l) );
    $this->assert_str_equals( "blah", $l[0]->{token} );
    $this->assert_str_equals( "clah", $l[1]->{token} );
}

sub test_addRemove {
    my $this  = shift;
    my $locks = new Filesys::Virtual::Locks( $this->{db} );

    # Add infinite locks on all nodes
    $locks->addLock( token => "1", path => 'a',     depth => -1 );
    $locks->addLock( token => "2", path => 'a/b',   depth => -1 );
    $locks->addLock( token => "3", path => 'a/b/c', depth => -1 );

    $locks = new Filesys::Virtual::Locks( $this->{db} );
    my @l = $locks->getLocks('a/b/c');
    $this->assert_equals( 3, scalar(@l) );
    $this->assert_str_equals( "1", $l[0]->{token} );
    $this->assert_str_equals( "2", $l[1]->{token} );
    $this->assert_str_equals( "3", $l[2]->{token} );

    # Remove the lock on the middle node
    $locks->removeLock('2');

    $locks = new Filesys::Virtual::Locks( $this->{db} );
    @l     = $locks->getLocks('a/b/c');
    $this->assert_equals( 2, scalar(@l) );
    $this->assert_str_equals( "1", $l[0]->{token} );
    $this->assert_str_equals( "3", $l[1]->{token} );

    # Add a new depth=0 lock to the mid level - this will only
    # lock that level, so won't apply to a/b/c
    $locks->addLock( token => "2", path => 'a/b', depth => 0 );

    $locks = new Filesys::Virtual::Locks( $this->{db} );
    @l     = $locks->getLocks('a/b/c');
    $this->assert_equals( 2, scalar(@l) );
    $this->assert_str_equals( "1", $l[0]->{token} );
    $this->assert_str_equals( "3", $l[1]->{token} );
    @l = $locks->getLocks('a/b');
    $this->assert_equals( 2, scalar(@l) );
    $this->assert_str_equals( "1", $l[0]->{token} );
    $this->assert_str_equals( "2", $l[1]->{token} );

    # Check that a recursive call gets all the locks
    @l = $locks->getLocks( 'a', -1 );
    $this->assert_equals( 3, scalar(@l) );
    $this->assert_str_equals( "1", $l[0]->{token} );
    $this->assert_str_equals( "2", $l[1]->{token} );
    $this->assert_str_equals( "3", $l[2]->{token} );

    # Now add a side path
    $locks->addLock( token => "4", path => 'a/d', depth => -1 );
    @l = $locks->getLocks('a/d');
    $this->assert_equals( 2, scalar(@l) );
    $this->assert_str_equals( "1", $l[0]->{token} );
    $this->assert_str_equals( "4", $l[1]->{token} );

    # Check that a recursive call gets all the locks
    $locks = new Filesys::Virtual::Locks( $this->{db} );
    @l = $locks->getLocks( 'a', -1 );
    $this->assert_equals( 4, scalar(@l) );
    $this->assert_str_equals( "1", $l[0]->{token} );
    $this->assert_str_equals( "2", $l[1]->{token} );
    $this->assert_str_equals( "3", $l[3]->{token} );
    $this->assert_str_equals( "4", $l[2]->{token} );
}

1;
