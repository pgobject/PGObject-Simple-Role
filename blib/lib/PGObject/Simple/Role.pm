package PGObject::Simple::Role;

use 5.006;
use strict;
use warnings;
use Moo::Role;
use PGObject::Simple;
use Carp;

=head1 NAME

PGObject::Simple::Role - Moo/Moose mappers for minimalist PGObject framework

=head1 VERSION

Version 0.51 

=cut

our $VERSION = '0.51';


=head1 SYNOPSIS

Take the following (Moose) class:

    package MyAPP::Foo;
    use Moose;
    with 'PGObject::Simple::Role';

    has id  => (is => 'ro', isa => 'Int', required => 0);
    has foo => (is => 'ro', isa => 'Str', required => 0);
    has bar => (is => 'ro', isa => 'Str', required => 0);
    has baz => (is => 'ro', isa => 'Int', required => 0);

    sub get_dbh {
        return DBI->connect('dbi:Pg:dbname=foobar');
    }
    dbmethod(int => (funcname => 'foo_to_int'));

And a stored procedure:  

    CREATE OR REPLACE FUNCTION foo_to_int
    (in_id int, in_foo text, in_bar text, in_baz int)
    RETURNS INT LANGUAGE SQL AS
    $$
    select char_length($2) + char_length($3) + $1 * $4;
    $$;

Then the following Perl code would work to invoke it:

    my $foobar = MyApp->foo(id => 3, foo => 'foo', bar => 'baz', baz => 33);
    $foobar->call_dbmethod(funcname => 'foo_to_int');

The following will also work since you have the dbmethod call above:

    my $int = $foobar->int;

The full interface of call_dbmethod and call_procedure from PGObject::Simple are
supported, and call_dbmethod is effectively wrapped by dbmethod(), allowing a
declarative mapping.

=head1 DESCRIPTION



=head1 ATTRIBUTES AND LAZY GETTERS

=cut

# Private attribute for database handle, not intended to be directly set.

has _DBH => ( 
       is => 'lazy', 
       isa => sub { 
                    croak "Expected a database handle.  Got $_[0] instead"
                       unless eval {$_[0]->isa('DBI::db')};
       },
);

sub _build__DBH {
    my ($self) = @_;
    return $self->_get_dbh;
}

has _Registry => (is => 'lazy');

sub _build__Registry {
    return _get_registry();
}

=head2 _get_registry

This is a method the consuming classes can override in order to set the
registry of the calls for type mapping purposes.

=cut

sub _get_registry{
    return undef;
}

has _funcprefix => (is => 'lazy');

=head2 _get_prefix

Returns string, default is an empty string, used to set a prefix for mapping
stored prcedures to an object class.

=cut

sub _build__funcprefix {
    return $_[0]->_get_prefix;
}

sub _get_prefix {
    return '';
}

has _PGObject_Simple => (
    is => 'lazy',
);

sub _build__PGObject_Simple {
    my ($self) = @_;
    return PGObject::Simple->new() unless ref $self;
    $self->_DBH;
    $self->_funcprefix;
    my $obj = PGObject::Simple->new(%$self);
    $obj->_set_registry($self->_registry);
    return $obj;
}

has _registry => ( is => 'lazy' );

sub _build__registry {
    return _get_registry();
}

=head2 _get_dbh

Subclasses or sub-roles MUST implement a function which returns a DBI database
handle (DBD::Pg 2.0 or hgher required).  If this is not overridden an exception
will be raised.

=cut

sub _get_dbh {
    croak 'Subclasses MUST set their own get_dbh methods!';
}

=head2 call_procedure

Identical interface to PGObject::Simple->call_procedure.

This can be used on objects or on the packages themselves.  I.e.  
mypackage->call_procedure() and $myobject->call_procedure() both work.

=cut

sub call_procedure {
    my $self = shift @_;
    my %args = @_;
    my $obj = _build__PGObject_Simple($self);
    $obj->{_DBH} = "$self"->_get_dbh unless ref $self;
    if (ref $self){
        $args{funcprefix} = $self->_get_prefix;
    } else {
        $args{funcprefix} = "$self"->_get_prefix;
    }
    return $obj->call_procedure(%args);
}

=head2 call_dbmethod

Identical interface to PGObject::Simple->call_dbmethod

This can be used on objects or on the packages themselves.  I.e.  
mypackage->call_dbmethod() and $myobject->call_dbmethod() both work.

=cut

sub call_dbmethod {
    my $self = shift @_;
    my %args = @_;
    my $obj = _build__PGObject_Simple($self);
    $obj->{_DBH} = "$self"->_get_dbh unless ref $self;
    if (ref $self){
        $args{funcprefix} = $self->_get_prefix unless defined $args{funcprefix};
    } else {
        $args{funcprefix} = "$self"->_get_prefix 
                              unless defined $args{funcprefix};
    }
    $obj->call_dbmethod(%args);
}

=head2 dbmethod

use as dbmethod (name => (default_arghash))

For example:

  package MyObject;
  use Moo;
  with 'PGObject::Simple::Role';
  dbmethod(save => (
                                 strict_args => 0,
                                    funcname => 'save_user', 
                                      schema => 'public',
                                        args => { admin => 0 },
  );
  $MyObject->save(args => {username => 'foo', password => 'bar'});

Special arguments are:

=over

=item strict_args

If true, args override args provided by user.

=item returns_objects

If true, bless returned hashrefs before returning them.

=back

=cut


sub dbmethod {
    my $name = shift;
    my %defaultargs = @_;
    my ($target) = caller;

    my $coderef = sub {
       my $self = shift @_;
       my %args = @_;
       for my $key (keys %{$defaultargs{args}}){
           $args{args}->{$key} = $defaultargs{args}->{$key} 
                  unless $args{args}->{$key} or $defaultargs{strict_args};
       }
       for my $key(keys %defaultargs){
           next if grep(/^$key$/, qw(strict_args args returns_objects));
           $args{$key} = $defaultargs{$key} if $defaultargs{$key};
       }
       my @results = $self->call_dbmethod(%args);
       if ($defaultargs{returns_objects}){
           for my $ref(@results){
               $ref = "$target"->new(%$ref);
           }
       }
       return @results;
    };
    no strict 'refs';
    *{"${target}::${name}"} = $coderef;
}

=head1 AUTHOR

Chris Travers,, C<< <chris.travers at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-pgobject-simple-role at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=PGObject-Simple-Role>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PGObject::Simple::Role


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=PGObject-Simple-Role>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/PGObject-Simple-Role>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/PGObject-Simple-Role>

=item * Search CPAN

L<http://search.cpan.org/dist/PGObject-Simple-Role/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Chris Travers,.

Redistribution and use in source and compiled forms with or without 
modification, are permitted provided that the following conditions are met:

=over

=item 

Redistributions of source code must retain the above
copyright notice, this list of conditions and the following disclaimer as the
first lines of this file unmodified.

=item 

Redistributions in compiled form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
source code, documentation, and/or other materials provided with the 
distribution.

=back

THIS SOFTWARE IS PROVIDED BY THE AUTHOR(S) "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE AUTHOR(S) BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

1; # End of PGObject::Simple::Role
